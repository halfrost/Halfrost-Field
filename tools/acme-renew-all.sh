#!/usr/bin/env bash
set -Eeuo pipefail

# One-time setup / re-run-safe ACME configuration for halfrost.com.
# - Server domains: issue RSA certs via AliDNS and install them for nginx.
# - high-traffic public domains additionally get ECC certs.
# - Qiniu image CDN: issue RSA cert via AliDNS and deploy it to Qiniu.
#
# Run as root on the cloud server:
#   sudo -i
#   export Ali_Key="..."
#   export Ali_Secret="..."
#   export QINIU_AK="..."
#   export QINIU_SK="..."
#   bash /path/to/tools/acme-renew-all.sh

ACME_SH="${ACME_SH:-$HOME/.acme.sh/acme.sh}"
ACME_HOME="${ACME_HOME:-$(dirname "$ACME_SH")}"
CERT_BASE="${CERT_BASE:-/etc/letsencrypt/live}"
DEFAULT_CA="${DEFAULT_CA:-letsencrypt}"
FORCE_SERVER_RSA="${FORCE_SERVER_RSA:-false}"
FORCE_SERVER_ECC="${FORCE_SERVER_ECC:-false}"
FORCE_QINIU_RSA="${FORCE_QINIU_RSA:-false}"

NGINX_RELOAD_CMD="${NGINX_RELOAD_CMD:-systemctl reload nginx || service nginx reload || service nginx restart}"

QINIU_DOMAIN="${QINIU_DOMAIN:-img.halfrost.com}"
export QINIU_CDN_DOMAIN="${QINIU_CDN_DOMAIN:-$QINIU_DOMAIN}"
export QINIU_FORCE_HTTPS="${QINIU_FORCE_HTTPS:-true}"

SERVER_CERTS=(
  "halfrost.com www.halfrost.com"
  "threes.halfrost.com www.threes.halfrost.com"
  "jupyter.halfrost.com www.jupyter.halfrost.com"
  "books.halfrost.com www.books.halfrost.com"
  "new.halfrost.com www.new.halfrost.com"
)

ECC_PRIMARY_DOMAINS=(
  "halfrost.com"
  "threes.halfrost.com"
  "books.halfrost.com"
)

log() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Run this script as root because it writes to ${CERT_BASE} and controls nginx."
  fi
}

require_file() {
  [[ -x "$1" ]] || die "Missing executable: $1"
}

require_env() {
  local name
  for name in "$@"; do
    [[ -n "${!name:-}" ]] || die "Missing environment variable: ${name}"
  done
}

has_ecc_cert() {
  local primary="$1"
  local domain
  for domain in "${ECC_PRIMARY_DOMAINS[@]}"; do
    [[ "$domain" == "$primary" ]] && return 0
  done
  return 1
}

acme_cert_file() {
  local primary="$1"
  local cert_kind="$2"
  local cert_dir="${ACME_HOME}/${primary}"

  if [[ "$cert_kind" == "ecc" ]]; then
    cert_dir="${ACME_HOME}/${primary}_ecc"
  fi

  printf '%s/%s.cer' "$cert_dir" "$primary"
}

run_issue_or_continue() {
  local primary="$1"
  local cert_kind="$2"
  shift 2

  local cert_file
  cert_file="$(acme_cert_file "$primary" "$cert_kind")"

  set +e
  "$ACME_SH" --issue "$@"
  local rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    return 0
  fi

  if [[ -s "$cert_file" ]]; then
    log "Issue command returned ${rc}, but existing ${cert_kind^^} certificate is present: ${cert_file}"
    log "Continue with install/deploy. This usually means acme.sh skipped because renewal is not due yet."
    return 0
  fi

  die "acme.sh issue failed for ${primary} (${cert_kind}) and no existing certificate was found at ${cert_file}"
}

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y) return 0 ;;
    *) return 1 ;;
  esac
}

issue_server_cert() {
  local keylength="$1"
  local cert_kind="$2"
  local primary="$3"
  shift 3

  local cert_dir="${CERT_BASE}/${primary}"

  if [[ "$cert_kind" == "ecc" ]]; then
    cert_dir="${CERT_BASE}/${primary}/ecc"
  fi

  mkdir -p "$cert_dir"

  local issue_force_arg=""
  if [[ "$cert_kind" == "rsa" ]] && is_true "$FORCE_SERVER_RSA"; then
    issue_force_arg="--force"
  fi
  if [[ "$cert_kind" == "ecc" ]] && is_true "$FORCE_SERVER_ECC"; then
    issue_force_arg="--force"
  fi

  log "Issue ${cert_kind^^} certificate for: $*"
  if [[ -n "$issue_force_arg" ]]; then
    run_issue_or_continue "$primary" "$cert_kind" \
      "$@" \
      --dns dns_ali \
      --keylength "$keylength" \
      "$issue_force_arg"
  else
    run_issue_or_continue "$primary" "$cert_kind" \
      "$@" \
      --dns dns_ali \
      --keylength "$keylength"
  fi

  log "Install ${cert_kind^^} certificate for ${primary} into ${cert_dir}"
  if [[ "$cert_kind" == "ecc" ]]; then
    "$ACME_SH" --install-cert -d "$primary" --ecc \
      --key-file "${cert_dir}/privkey.pem" \
      --fullchain-file "${cert_dir}/fullchain.pem" \
      --reloadcmd "$NGINX_RELOAD_CMD"
  else
    "$ACME_SH" --install-cert -d "$primary" \
      --key-file "${cert_dir}/privkey.pem" \
      --fullchain-file "${cert_dir}/fullchain.pem" \
      --reloadcmd "$NGINX_RELOAD_CMD"
  fi
}

setup_server_domain_group() {
  local domains_text="$1"
  local domains=()
  read -r -a domains <<< "$domains_text"

  local acme_domain_args=()
  local domain
  for domain in "${domains[@]}"; do
    acme_domain_args+=(-d "$domain")
  done

  issue_server_cert "2048" "rsa" "${domains[0]}" "${acme_domain_args[@]}"

  if has_ecc_cert "${domains[0]}"; then
    issue_server_cert "ec-256" "ecc" "${domains[0]}" "${acme_domain_args[@]}"
  fi
}

setup_qiniu_cert() {
  require_env Ali_Key Ali_Secret QINIU_AK QINIU_SK

  local issue_force_arg=""
  if is_true "$FORCE_QINIU_RSA"; then
    issue_force_arg="--force"
  fi

  log "Issue Qiniu CDN certificate for ${QINIU_DOMAIN} via AliDNS"
  if [[ -n "$issue_force_arg" ]]; then
    run_issue_or_continue "$QINIU_DOMAIN" "rsa" \
      -d "$QINIU_DOMAIN" \
      --dns dns_ali \
      --keylength 2048 \
      "$issue_force_arg"
  else
    run_issue_or_continue "$QINIU_DOMAIN" "rsa" \
      -d "$QINIU_DOMAIN" \
      --dns dns_ali \
      --keylength 2048
  fi

  log "Deploy ${QINIU_DOMAIN} certificate to Qiniu CDN domain ${QINIU_CDN_DOMAIN}"
  "$ACME_SH" --deploy \
    -d "$QINIU_DOMAIN" \
    --deploy-hook qiniu
}

show_nginx_snippets() {
  local domains_text primary

  log "Nginx certificate snippets"
  for domains_text in "${SERVER_CERTS[@]}"; do
    primary="${domains_text%% *}"
    cat <<EOF

# ${primary}
ssl_certificate     ${CERT_BASE}/${primary}/fullchain.pem;
ssl_certificate_key ${CERT_BASE}/${primary}/privkey.pem;
EOF

    if has_ecc_cert "$primary"; then
      cat <<EOF
ssl_certificate     ${CERT_BASE}/${primary}/ecc/fullchain.pem;
ssl_certificate_key ${CERT_BASE}/${primary}/ecc/privkey.pem;
EOF
    fi
  done
}

main() {
  require_root
  require_file "$ACME_SH"
  require_env Ali_Key Ali_Secret

  log "Use acme.sh: $ACME_SH"
  log "Use acme.sh home: $ACME_HOME"
  log "Force flags: FORCE_SERVER_RSA=${FORCE_SERVER_RSA}, FORCE_SERVER_ECC=${FORCE_SERVER_ECC}, FORCE_QINIU_RSA=${FORCE_QINIU_RSA}"
  "$ACME_SH" --set-default-ca --server "$DEFAULT_CA"

  local domains_text
  for domains_text in "${SERVER_CERTS[@]}"; do
    setup_server_domain_group "$domains_text"
  done

  setup_qiniu_cert

  log "Ensure acme.sh cron job is installed"
  "$ACME_SH" --install-cronjob

  show_nginx_snippets

  log "Done. Test the scheduled renewal check with: ${ACME_SH} --cron --home ${HOME}/.acme.sh"
}

main "$@"
