package cmap

const (
	// DEFAULT_BUCKET_LOAD_FACTOR 代表默认的装载因子。
	// 当散列段中的某个散列桶的尺寸超过了
	// 本因子与当散列段尺寸的乘积，就会触发再散列。
	DEFAULT_BUCKET_LOAD_FACTOR float64 = 0.75
	// DEFAULT_BUCKET_NUMBER 代表一个散列段包含的散列桶的默认数量。
	DEFAULT_BUCKET_NUMBER int = 16
	// DEFAULT_BUCKET_MAX_SIZE 代表单个散列桶的默认最大尺寸。
	DEFAULT_BUCKET_MAX_SIZE uint64 = 1000
)

const (
	// MAX_CONCURRENCY 代表最大并发量。
	MAX_CONCURRENCY int = 65536
)
