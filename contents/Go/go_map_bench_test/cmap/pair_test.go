package cmap

import (
	"bytes"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"math/rand"
	"testing"
)

// keyElement 用于存储键-元素对。
type keyElement struct {
	key     string
	element interface{}
}

func TestPairNew(t *testing.T) {
	testCases := genTestingKeyElementSlice(100)
	testCases[0] = &keyElement{"", randElement()}
	for _, tc := range testCases {
		t.Run(fmt.Sprintf("Key=%s,Element=%#v", tc.key, tc.element),
			func(t *testing.T) {
				p, err := newPair(tc.key, tc.element)
				if err != nil {
					t.Fatalf("An error occurs when new a pair: %s (key: %s, element: %#v)",
						err, tc.key, tc.element)
				}
				if p == nil {
					t.Fatalf("Couldn't new pair! (key: %s, element: %#v)",
						tc.key, tc.element)
				}
			})
	}
}

func TestPairKeyAndHashAndElement(t *testing.T) {
	testCases := genTestingKeyElementSlice(30)
	for _, tc := range testCases {
		t.Run(fmt.Sprintf("Key=%s,Element=%#v", tc.key, tc.element),
			func(t *testing.T) {
				p, err := newPair(tc.key, tc.element)
				if err != nil {
					t.Fatalf("An error occurs when new a pair: %s (key: %s, element: %#v)",
						err, tc.key, tc.element)
				}
				if p.Key() != tc.key {
					t.Fatalf("Inconsistent key: expected: %s, actual: %s",
						tc.key, p.Key())
				}
				expectedHash := hash(tc.key)
				if p.Hash() != expectedHash {
					t.Fatalf("Inconsistent hash: expected: %d, actual: %d",
						expectedHash, p.Hash())
				}
				if p.Element() != tc.element {
					t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
						tc.element, p.Element())
				}
			})
	}
}

func TestPairSet(t *testing.T) {
	testCases := genTestingKeyElementSlice(30)
	for _, tc := range testCases {
		t.Run(fmt.Sprintf("Key=%s,Element=%#v", tc.key, tc.element),
			func(t *testing.T) {
				p, err := newPair(tc.key, tc.element)
				if err != nil {
					t.Fatalf("An error occurs when new a pair: %s (key: %s, element: %#v)",
						err, tc.key, tc.element)
				}
				newElement := randString()
				p.SetElement(newElement)
				if p.Element() != newElement {
					t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
						newElement, p.Element())
				}
			})
	}
}

func TestPairNext(t *testing.T) {
	number := 30
	testCases := genTestingKeyElementSlice(number)
	var current Pair
	var prev Pair
	var err error
	for _, tc := range testCases {
		current, err = newPair(tc.key, tc.element)
		if err != nil {
			t.Fatalf("An error occurs when new a pair: %s (key: %s, element: %#v)",
				err, tc.key, tc.element)
		}
		if prev != nil {
			current.SetNext(prev)
		}
		prev = current
	}
	for i := number - 1; i >= 0; i-- {
		next := current.Next()
		if i == 0 {
			if next != nil {
				t.Fatalf("Next is not nil! (pair: %#v, index: %d)",
					current, i)
			}
		} else {
			if next == nil {
				t.Fatalf("Next is nil! (pair: %#v, index: %d)",
					current, i)
			}
			expectedNext := testCases[i-1]
			if next.Key() != expectedNext.key {
				t.Fatalf("Inconsistent next key: expected: %s, actual: %s, index: %d",
					expectedNext.key, next.Key(), i)
			}
			if next.Element() != expectedNext.element {
				t.Fatalf("Inconsistent element: expected: %#v, actual: %#v, index: %d",
					expectedNext.element, next.Element(), i)
			}
		}
		current = next
	}
}

func TestPairCopy(t *testing.T) {
	testCases := genTestingKeyElementSlice(30)
	for _, tc := range testCases {
		t.Run(fmt.Sprintf("Key=%s,Element=%#v", tc.key, tc.element),
			func(t *testing.T) {
				p, err := newPair(tc.key, tc.element)
				if err != nil {
					t.Fatalf("An error occurs when new a pair: %s (key: %s, element: %#v)",
						err, tc.key, tc.element)
				}
				pCopy := p.Copy()
				if pCopy.Key() != p.Key() {
					t.Fatalf("Inconsistent key: expected: %s, actual: %s",
						p.Key(), pCopy.Key())
				}
				if pCopy.Hash() != p.Hash() {
					t.Fatalf("Inconsistent hash: expected: %d, actual: %d",
						p.Hash(), pCopy.Hash())
				}
				if pCopy.Element() != p.Element() {
					t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
						p.Element(), pCopy.Element())
				}
			})
	}
}

// genTestingKeyElementSlice 用于生成测试用的键-元素对的切片。
func genTestingKeyElementSlice(number int) []*keyElement {
	testCases := make([]*keyElement, number)
	for i := 0; i < number; i++ {
		testCases[i] =
			&keyElement{randString(), randElement()}
	}
	return testCases
}

// randElement 会生成并返回一个伪随机元素值。
func randElement() interface{} {
	if i := rand.Int31(); i%3 != 0 {
		return i
	}
	buf := new(bytes.Buffer)
	binary.Write(buf, binary.LittleEndian, rand.Int31())
	return hex.EncodeToString(buf.Bytes())
}

// randString 会生成并返回一个伪随机字符串。
func randString() string {
	buf := new(bytes.Buffer)
	binary.Write(buf, binary.LittleEndian, rand.Int31())
	return hex.EncodeToString(buf.Bytes())
}
