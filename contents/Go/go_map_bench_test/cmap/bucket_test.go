package cmap

import (
	"fmt"
	"sync"
	"testing"
	"time"
)

func TestBucketNew(t *testing.T) {
	b := newBucket()
	if b == nil {
		t.Fatal("Couldn't new bucket!")
	}
}

func TestBucketPut(t *testing.T) {
	number := 30
	testCases := genTestingPairs(number)
	b := newBucket()
	var count uint64
	for _, p := range testCases {
		ok, err := b.Put(p, nil)
		if err != nil {
			t.Fatalf("An error occurs when putting a pair to the bucket: %s (pair: %#v)",
				err, p)
		}
		if !ok {
			t.Fatalf("Couldn't put pair to the bucket! (pair: %#v)",
				p)
		}
		actualPair := b.Get(p.Key())
		if actualPair == nil {
			t.Fatalf("Inconsistent pair: expected: %#v, actual: %#v",
				p.Element(), nil)
		}
		ok, err = b.Put(p, nil)
		if err != nil {
			t.Fatalf("An error occurs when putting a repeated pair to the bucket: %s (pair: %#v)",
				err, p)
		}
		if ok {
			t.Fatalf("Couldn't put repeated pair to the bucket! (pair: %#v)",
				p)
		}
		count++
		if b.Size() != count {
			t.Fatalf("Inconsistent size: expected: %d, actual: %d",
				count, b.Size())
		}
	}
	if b.Size() != uint64(number) {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			number, b.Size())
	}
}

func TestBucketPutInParallel(t *testing.T) {
	number := 30
	testCases := genNoRepetitiveTestingPairs(number)
	b := newBucket()
	lock := new(sync.Mutex)
	testingFunc := func(p Pair, t *testing.T) func(t *testing.T) {
		return func(t *testing.T) {
			t.Parallel()
			ok, err := b.Put(p, lock)
			if err != nil {
				t.Fatalf("An error occurs when putting a pair to the bucket: %s (pair: %#v)",
					err, p)
			}
			if !ok {
				t.Fatalf("Couldn't put a pair to the bucket! (pair: %#v)", p)
			}
			actualPair := b.Get(p.Key())
			if actualPair == nil {
				t.Fatalf("Inconsistent pair: expected: %#v, actual: %#v",
					p.Element(), nil)
			}
			ok, err = b.Put(p, lock)
			if err != nil {
				t.Fatalf("An error occurs when putting a repeated pair to the bucket: %s (pair: %#v)",
					err, p)
			}
			if ok {
				t.Fatalf("Couldn't put a repeated pair to the bucket! (pair: %#v)", p)
			}
		}
	}
	t.Run("Put in parallel", func(t *testing.T) {
		for _, p := range testCases {
			t.Run(fmt.Sprintf("Key=%s", p.Key()), testingFunc(p, t))
		}
	})
	if b.Size() != uint64(number) {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			number, b.Size())
	}
}

func TestBucketGetInParallel(t *testing.T) {
	number := 30
	testCases := genNoRepetitiveTestingPairs(number)
	b := newBucket()
	for _, p := range testCases {
		b.Put(p, nil)
	}
	testingFunc := func(p Pair, t *testing.T) func(t *testing.T) {
		return func(t *testing.T) {
			t.Parallel()
			actualPair := b.Get(p.Key())
			if actualPair == nil {
				t.Fatalf("Not found pair in bucket! (key: %s)",
					p.Key())
			}
			if actualPair.Key() != p.Key() {
				t.Fatalf("Inconsistent key: expected: %s, actual: %s",
					p.Key(), actualPair.Key())
			}
			if actualPair.Hash() != p.Hash() {
				t.Fatalf("Inconsistent hash: expected: %d, actual: %d",
					p.Hash(), actualPair.Hash())
			}
			if actualPair.Element() != p.Element() {
				t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
					p.Element(), actualPair.Element())
			}
		}
	}
	t.Run("Get in parallel", func(t *testing.T) {
		t.Run("Put in parallel", func(t *testing.T) {
			for _, p := range testCases {
				b.Put(p, nil)
			}
		})
		for _, p := range testCases {
			t.Run(fmt.Sprintf("Get: Key=%s", p.Key()), testingFunc(p, t))
		}
	})
	if b.Size() != uint64(number) {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			number, b.Size())
	}
}

func TestBucketGetFirstPair(t *testing.T) {
	number := 30
	testCases := genTestingPairs(number)
	b := newBucket()
	for _, p := range testCases {
		b.Put(p, nil)
	}
	size := b.Size()
	if size != uint64(number) {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			number, size)
	}
	current := b.GetFirstPair()
	for i := int(size - 1); i >= 0; i-- {
		expectedPair := testCases[i]
		if current.Key() != expectedPair.Key() {
			t.Fatalf("Inconsistent key: expected: %s, actual: %s",
				expectedPair.Key(), current.Key())
		}
		if current.Element() != expectedPair.Element() {
			t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
				expectedPair.Element(), current.Element())
		}
		current = current.Next()
	}
	if current != nil {
		t.Fatal("The next of the last pair in bucket is not nil!")
	}
	if b.Size() != uint64(number) {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			number, b.Size())
	}
}

func TestBucketDelete(t *testing.T) {
	number := 30
	testCases := genTestingPairs(number)
	b := newBucket()
	for _, p := range testCases {
		b.Put(p, nil)
	}
	count := uint64(number)
	for _, p := range testCases {
		done := b.Delete(p.Key(), nil)
		if !done {
			t.Fatalf("Couldn't delete a pair from bucket! (pair: %#v)", p)
		}
		actualPair := b.Get(p.Key())
		if actualPair != nil {
			t.Fatalf("Inconsistent pair: expected: %#v, actual: %#v",
				nil, actualPair)
		}
		done = b.Delete(p.Key(), nil)
		if done {
			t.Fatalf("Couldn't delete a pair from bucket again! (pair: %#v)", p)
		}
		if count > 0 {
			count--
		}
		if b.Size() != count {
			t.Fatalf("Inconsistent size: expected: %d, actual: %d",
				count, b.Size())
		}
	}
	if b.Size() != 0 {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			0, b.Size())
	}
}

func TestBucketDeleteInParallel(t *testing.T) {
	number := 30
	testCases := genNoRepetitiveTestingPairs(number)
	b := newBucket()
	for _, p := range testCases {
		b.Put(p, nil)
	}
	lock := new(sync.Mutex)
	testingFunc := func(p Pair, t *testing.T) func(t *testing.T) {
		return func(t *testing.T) {
			t.Parallel()
			done := b.Delete(p.Key(), lock)
			if !done {
				t.Fatalf("Couldn't delete a pair from bucket! (pair: %#v)", p)
			}
			actualPair := b.Get(p.Key())
			if actualPair != nil {
				t.Fatalf("Inconsistent pair: expected: %#v, actual: %#v",
					nil, actualPair)
			}
			done = b.Delete(p.Key(), lock)
			if done {
				t.Fatalf("Couldn't delete a pair from bucket again! (pair: %#v)", p)
			}
		}
	}
	t.Run("Delete in parallel", func(t *testing.T) {
		for _, p := range testCases {
			t.Run(fmt.Sprintf("Key=%s", p.Key()), testingFunc(p, t))
		}
	})
	if b.Size() != 0 {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			0, b.Size())
	}
}

func TestBucketClear(t *testing.T) {
	number := 10
	testCases := genTestingPairs(number)
	b := newBucket()
	for _, p := range testCases {
		b.Put(p, nil)
	}
	b.Clear(nil)
	if b.Size() != 0 {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			0, b.Size())
	}
}

func TestBucketClearInParallel(t *testing.T) {
	number := 1000
	testCases := genTestingPairs(number)
	b := newBucket()
	lock := new(sync.Mutex)
	t.Run("Clear in parallel", func(t *testing.T) {
		t.Run("Put", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases {
				ok, err := b.Put(p, lock)
				if err != nil {
					t.Fatalf("An error occurs when putting a pair to the bucket: %s (pair: %#v)",
						err, p)
				}
				if !ok {
					t.Fatalf("Couldn't put pair to the bucket! (pair: %#v)",
						p)
				}
			}
		})
		t.Run("Clear", func(t *testing.T) {
			t.Parallel()
			for i := number; i >= 0; i-- {
				b.Clear(lock)
			}
		})
	})
	if b.Size() > 0 {
		t.Log("Not clear. Clear again.")
		b.Clear(nil)
	}
	if b.Size() != 0 {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			0, b.Size())
	}
}

var testCaseNumberForBucketTest = 200000
var testCasesForBucketTest = genNoRepetitiveTestingPairs(testCaseNumberForBucketTest)
var testCases1ForBucketTest = testCasesForBucketTest[:testCaseNumberForBucketTest/2]
var testCases2ForBucketTest = testCasesForBucketTest[testCaseNumberForBucketTest/2:]

func TestBucketAllInParallel(t *testing.T) {
	testCases1 := testCases1ForBucketTest
	testCases2 := testCases2ForBucketTest
	b := newBucket()
	lock := new(sync.Mutex)
	t.Run("All in parallel", func(t *testing.T) {
		t.Run("Put1", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases1 {
				existingPair := b.Get(p.Key())
				if existingPair != nil {
					b.Delete(p.Key(), lock)
				}
				ok, err := b.Put(p, lock)
				if !ok {
					t.Fatalf("Couldn't put a pair to the bucket! (pair: %#v)", p)
				}
				if err != nil {
					t.Fatalf("An error occurs when putting a pair to the bucket: %s (pair: %#v)",
						err, p)
				}
			}
		})
		t.Run("Put2", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases2 {
				existingPair := b.Get(p.Key())
				if existingPair != nil {
					b.Delete(p.Key(), lock)
				}
				ok, err := b.Put(p, lock)
				if !ok {
					t.Fatalf("Couldn't put a pair to the bucket! (pair: %#v)", p)
				}
				if err != nil {
					t.Fatalf("An error occurs when putting a pair to the bucket: %s (pair: %#v)",
						err, p)
				}
			}
		})
		t.Run("Get1", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases1 {
				actualPair := b.Get(p.Key())
				if actualPair == nil {
					continue
				}
				if actualPair.Key() != p.Key() {
					t.Fatalf("Inconsistent key: expected: %s, actual: %s",
						p.Key(), actualPair.Key())
				}
				if actualPair.Hash() != p.Hash() {
					t.Fatalf("Inconsistent hash: expected: %d, actual: %d",
						p.Hash(), actualPair.Hash())
				}
				if actualPair.Element() != p.Element() {
					t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
						p.Element(), actualPair.Element())
				}
			}
		})
		t.Run("Get2", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases2 {
				actualPair := b.Get(p.Key())
				if actualPair == nil {
					continue
				}
				if actualPair.Key() != p.Key() {
					t.Fatalf("Inconsistent key: expected: %s, actual: %s",
						p.Key(), actualPair.Key())
				}
				if actualPair.Hash() != p.Hash() {
					t.Fatalf("Inconsistent hash: expected: %d, actual: %d",
						p.Hash(), actualPair.Hash())
				}
				if actualPair.Element() != p.Element() {
					t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
						p.Element(), actualPair.Element())
				}
			}
		})
		t.Run("Delete1", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases1 {
				b.Delete(p.Key(), lock)
			}
		})
		t.Run("Delete2", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases2 {
				b.Delete(p.Key(), lock)
			}
		})
		t.Run("Clear", func(t *testing.T) {
			t.Parallel()
			go func() {
				for _ = range time.Tick(time.Millisecond * 10) {
					b.Clear(lock)
				}
			}()
			time.Tick(time.Millisecond * 10)
		})
	})
}

// genTestingPairs 用于生成测试用的键-元素对的切片。
func genTestingPairs(number int) []Pair {
	testCases := make([]Pair, number)
	for i := 0; i < number; i++ {
		testCases[i], _ = newPair(randString(), randElement())
	}
	return testCases
}

// genNoRepetitiveTestingPairs 用于生成测试用的无重复的键-元素对的切片。
func genNoRepetitiveTestingPairs(number int) []Pair {
	testCases := make([]Pair, number)
	m := make(map[string]struct{})
	var p Pair
	for i := 0; i < number; i++ {
		for {
			p, _ = newPair(randString(), randElement())
			if _, ok := m[p.Key()]; !ok {
				testCases[i] = p
				m[p.Key()] = struct{}{}
				break
			}
		}
	}
	return testCases
}
