---
title: Changes to String in java (from 1.7.0_06)
date: 2020-06-06 09:00:00
tags:
- Algorithms
categories:
- notes
keywords:
    - Algorithms
    - String
    - radix sort
---


Before 1.7.0_06, `String` has 4 non static field:
* char[] value
* int[] offset
* int count
* int hash

`Subing.substring` create a String by sharing the original String's internal `char[] value` and setting offset. This saves memory and makes `String.substring` run in a constant time($O(1)$).
Meanwhile, this feature may cause **memory leak**[^1].

[http://hg.openjdk.java.net/jdk6/jdk6/jdk/file/8deef18bb749/src/share/classes/java/lang/String.java](http://hg.openjdk.java.net/jdk6/jdk6/jdk/file/8deef18bb749/src/share/classes/java/lang/String.java)
```Java
public final class String
    implements java.io.Serializable, Comparable<String>, CharSequence
{
    /** The value is used for character storage. */
    private final char value[];

    /** The offset is the first index of the storage that is used. */
    private final int offset;

    /** The count is the number of characters in the String. */
    private final int count;

    /** Cache the hash code for the string */
    private int hash; // Default to 0

    // ...

    // Package private constructor which shares value array for speed.
    String(int offset, int count, char value[]) {
        this.value = value;
        this.offset = offset;
        this.count = count;
    }

    // ...

    /**
     * Returns a new string that is a substring of this string. The
     * substring begins at the specified <code>beginIndex</code> and
     * extends to the character at index <code>endIndex - 1</code>.
     * Thus the length of the substring is <code>endIndex-beginIndex</code>.
     * <p>
     * Examples:
     * <blockquote><pre>
     * "hamburger".substring(4, 8) returns "urge"
     * "smiles".substring(1, 5) returns "mile"
     * </pre></blockquote>
     *
     * @param      beginIndex   the beginning index, inclusive.
     * @param      endIndex     the ending index, exclusive.
     * @return     the specified substring.
     * @exception  IndexOutOfBoundsException  if the
     *             <code>beginIndex</code> is negative, or
     *             <code>endIndex</code> is larger than the length of
     *             this <code>String</code> object, or
     *             <code>beginIndex</code> is larger than
     *             <code>endIndex</code>.
     */
    public String substring(int beginIndex, int endIndex) {
        if (beginIndex < 0) {
            throw new StringIndexOutOfBoundsException(beginIndex);
        }
        if (endIndex > count) {
            throw new StringIndexOutOfBoundsException(endIndex);
        }
        if (beginIndex > endIndex) {
            throw new StringIndexOutOfBoundsException(endIndex - beginIndex);
        }
        return ((beginIndex == 0) && (endIndex == count)) ? this :
            new String(offset + beginIndex, endIndex - beginIndex, value);
    }

    // ...
}
```

Since Java 1.7.0_06, `offset` and `count` fields were removed. `String.substring` makes new copies of `value`, which means we can forget about the memory leak but the runtime becomes $O(N)$ at the same time.

[http://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/lang/String.java](http://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/lang/String.java)
```Java

public final class String
    implements java.io.Serializable, Comparable<String>, CharSequence {
    /** The value is used for character storage. */
    private final char value[];

    /** Cache the hash code for the string */
    private int hash; // Default to 0

    // ...

  /**
     * Allocates a new {@code String} that contains characters from a subarray
     * of the character array argument. The {@code offset} argument is the
     * index of the first character of the subarray and the {@code count}
     * argument specifies the length of the subarray. The contents of the
     * subarray are copied; subsequent modification of the character array does
     * not affect the newly created string.
     *
     * @param  value
     *         Array that is the source of characters
     *
     * @param  offset
     *         The initial offset
     *
     * @param  count
     *         The length
     *
     * @throws  IndexOutOfBoundsException
     *          If the {@code offset} and {@code count} arguments index
     *          characters outside the bounds of the {@code value} array
     */
    public String(char value[], int offset, int count) {
        if (offset < 0) {
            throw new StringIndexOutOfBoundsException(offset);
        }
        if (count < 0) {
            throw new StringIndexOutOfBoundsException(count);
        }
        // Note: offset or count might be near -1>>>1.
        if (offset > value.length - count) {
            throw new StringIndexOutOfBoundsException(offset + count);
        }
        this.value = Arrays.copyOfRange(value, offset, offset+count);
    }

    // ...

/**
     * Returns a string that is a substring of this string. The
     * substring begins at the specified {@code beginIndex} and
     * extends to the character at index {@code endIndex - 1}.
     * Thus the length of the substring is {@code endIndex-beginIndex}.
     * <p>
     * Examples:
     * <blockquote><pre>
     * "hamburger".substring(4, 8) returns "urge"
     * "smiles".substring(1, 5) returns "mile"
     * </pre></blockquote>
     *
     * @param      beginIndex   the beginning index, inclusive.
     * @param      endIndex     the ending index, exclusive.
     * @return     the specified substring.
     * @exception  IndexOutOfBoundsException  if the
     *             {@code beginIndex} is negative, or
     *             {@code endIndex} is larger than the length of
     *             this {@code String} object, or
     *             {@code beginIndex} is larger than
     *             {@code endIndex}.
     */
    public String substring(int beginIndex, int endIndex) {
        if (beginIndex < 0) {
            throw new StringIndexOutOfBoundsException(beginIndex);
        }
        if (endIndex > value.length) {
            throw new StringIndexOutOfBoundsException(endIndex);
        }
        int subLen = endIndex - beginIndex;
        if (subLen < 0) {
            throw new StringIndexOutOfBoundsException(subLen);
        }
        return ((beginIndex == 0) && (endIndex == value.length)) ? this
                : new String(value, beginIndex, subLen);
    }

    // ...

}
```

The auther's comment[^2]:
<a class="embedly-card" href="https://www.reddit.com/r/programming/comments/1qw73v/til_oracle_changed_the_internal_string/cdhb77f">Card</a>
<script async src="//embed.redditmedia.com/widgets/platform.js" charset="UTF-8"></script>

[^1]: http://java-performance.info/changes-to-string-java-1-7-0_06/
[^2]: https://www.reddit.com/r/programming/comments/1qw73v/til_oracle_changed_the_internal_string/cdhb77f/