package cmap

import (
	"fmt"
	"testing"
)

func TestCmapNew(t *testing.T) {
	var concurrency int
	var pairRedistributor PairRedistributor
	cm, err := NewConcurrentMap(concurrency, pairRedistributor)
	if err == nil {
		t.Fatalf("No error when new a concurrent map with concurrency %d, but should not be the case!",
			concurrency)
	}
	concurrency = MAX_CONCURRENCY + 1
	cm, err = NewConcurrentMap(concurrency, pairRedistributor)
	if err == nil {
		t.Fatalf("No error when new a concurrent map with concurrency %d, but should not be the case!",
			concurrency)
	}
	concurrency = 16
	cm, err = NewConcurrentMap(concurrency, pairRedistributor)
	if err != nil {
		t.Fatalf("An error occurs when new a concurrent map: %s (concurrency: %d, pairRedistributor: %#v)",
			err, concurrency, pairRedistributor)
	}
	if cm == nil {
		t.Fatalf("Couldn't a new concurrent map! (concurrency: %d, pairRedistributor: %#v)",
			concurrency, pairRedistributor)
	}
	if cm.Concurrency() != concurrency {
		t.Fatalf("Inconsistent concurrency: expected: %d, actual: %d",
			concurrency, cm.Concurrency())
	}
}

func TestCmapPut(t *testing.T) {
	number := 30
	testCases := genTestingPairs(number)
	concurrency := 10
	var pairRedistributor PairRedistributor
	cm, _ := NewConcurrentMap(concurrency, pairRedistributor)
	var count uint64
	for _, p := range testCases {
		key := p.Key()
		element := p.Element()
		ok, err := cm.Put(key, element)
		if err != nil {
			t.Fatalf("An error occurs when putting a key-element to the cmap: %s (key: %s, element: %#v)",
				err, key, element)
		}
		if !ok {
			t.Fatalf("Couldn't put key-element to the cmap! (key: %s, element: %#v)",
				key, element)
		}
		actualElement := cm.Get(key)
		if actualElement == nil {
			t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
				element, nil)
		}
		ok, err = cm.Put(key, element)
		if err != nil {
			t.Fatalf("An error occurs when putting a repeated key-element to the cmap! %s (key: %s, element: %#v)",
				err, key, element)
		}
		if ok {
			t.Fatalf("Couldn't put key-element to the cmap! (key: %s, element: %#v)",
				key, element)
		}
		count++
		if cm.Len() != uint64(count) {
			t.Fatalf("Inconsistent size: expected: %d, actual: %d",
				count, cm.Len())
		}
	}
	if cm.Len() != uint64(number) {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			number, cm.Len())
	}
}

func TestCmapPutInParallel(t *testing.T) {
	number := 30
	testCases := genNoRepetitiveTestingPairs(number)
	concurrency := number / 2
	cm, _ := NewConcurrentMap(concurrency, nil)
	testingFunc := func(key string, element interface{}, t *testing.T) func(t *testing.T) {
		return func(t *testing.T) {
			t.Parallel()
			ok, err := cm.Put(key, element)
			if err != nil {
				t.Fatalf("An error occurs when putting a key-element to the cmap: %s (key: %s, element: %#v)",
					err, key, element)
			}
			if !ok {
				t.Fatalf("Couldn't put key-element to the cmap! (key: %s, element: %#v)",
					key, element)
			}
			actualElement := cm.Get(key)
			if actualElement == nil {
				t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
					element, nil)
			}
			ok, err = cm.Put(key, element)
			if err != nil {
				t.Fatalf("An error occurs when putting a repeated key-element to the cmap! %s (key: %s, element: %#v)",
					err, key, element)
			}
			if ok {
				t.Fatalf("Couldn't put key-element to the cmap! (key: %s, element: %#v)",
					key, element)
			}
		}
	}
	t.Run("Put in parallel", func(t *testing.T) {
		for _, p := range testCases {
			t.Run(fmt.Sprintf("Key=%s", p.Key()),
				testingFunc(p.Key(), p.Element(), t))
		}
	})
	if cm.Len() != uint64(number) {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			number, cm.Len())
	}
}

func TestCmapGetInParallel(t *testing.T) {
	number := 30
	testCases := genNoRepetitiveTestingPairs(number)
	concurrency := number / 2
	cm, _ := NewConcurrentMap(concurrency, nil)
	for _, p := range testCases {
		cm.Put(p.Key(), p.Element())
	}
	testingFunc := func(key string, element interface{}, t *testing.T) func(t *testing.T) {
		return func(t *testing.T) {
			t.Parallel()
			actualElement := cm.Get(key)
			if actualElement == nil {
				t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
					element, nil)
			}
			if actualElement != element {
				t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
					element, actualElement)
			}
		}
	}
	t.Run("Get in parallel", func(t *testing.T) {
		t.Run("Put in parallel", func(t *testing.T) {
			for _, p := range testCases {
				cm.Put(p.Key(), p.Element())
			}
		})
		for _, p := range testCases {
			t.Run(fmt.Sprintf("Get: Key=%s", p.Key()),
				testingFunc(p.Key(), p.Element(), t))
		}
	})
	if cm.Len() != uint64(number) {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			number, cm.Len())
	}
}

func TestCmapDelete(t *testing.T) {
	number := 30
	testCases := genTestingPairs(number)
	concurrency := number / 2
	cm, _ := NewConcurrentMap(concurrency, nil)
	for _, p := range testCases {
		cm.Put(p.Key(), p.Element())
	}
	count := uint64(number)
	for _, p := range testCases {
		done := cm.Delete(p.Key())
		if !done {
			t.Fatalf("Couldn't delete a key-element from cmap! (key: %s, element: %#v)",
				p.Key(), p.Element())
		}
		actualElement := cm.Get(p.Key())
		if actualElement != nil {
			t.Fatalf("Inconsistent key-element: expected: %#v, actual: %#v",
				nil, actualElement)
		}
		done = cm.Delete(p.Key())
		if done {
			t.Fatalf("Couldn't delete a key-element from cmap again! (key: %s, element: %#v)",
				p.Key(), p.Element())
		}
		if count > 0 {
			count--
		}
		if cm.Len() != count {
			t.Fatalf("Inconsistent size: expected: %d, actual: %d",
				count, cm.Len())
		}
	}
	if cm.Len() != 0 {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			0, cm.Len())
	}
}

func TestCmapDeleteInParallel(t *testing.T) {
	number := 30
	testCases := genNoRepetitiveTestingPairs(number)
	concurrency := number / 2
	cm, _ := NewConcurrentMap(concurrency, nil)
	for _, p := range testCases {
		cm.Put(p.Key(), p.Element())
	}
	testingFunc := func(key string, element interface{}, t *testing.T) func(t *testing.T) {
		return func(t *testing.T) {
			t.Parallel()
			done := cm.Delete(key)
			if !done {
				t.Fatalf("Couldn't delete a key-element from cmap! (key: %s, element: %#v)",
					key, element)
			}
			actualElement := cm.Get(key)
			if actualElement != nil {
				t.Fatalf("Inconsistent key-element: expected: %#v, actual: %#v",
					nil, actualElement)
			}
			done = cm.Delete(key)
			if done {
				t.Fatalf("Couldn't delete a key-element from cmap again! (key: %s, element: %#v)",
					key, element)
			}
		}
	}
	t.Run("Delete in parallel", func(t *testing.T) {
		for _, p := range testCases {
			t.Run(fmt.Sprintf("Key=%s", p.Key()),
				testingFunc(p.Key(), p.Element(), t))
		}
	})
	if cm.Len() != 0 {
		t.Fatalf("Inconsistent size: expected: %d, actual: %d",
			0, cm.Len())
	}
}

var testCaseNumberForCmapTest = 200000
var testCasesForCmapTest = genNoRepetitiveTestingPairs(testCaseNumberForCmapTest)
var testCases1ForCmapTest = testCasesForCmapTest[:testCaseNumberForCmapTest/2]
var testCases2ForCmapTest = testCasesForCmapTest[testCaseNumberForCmapTest/2:]

func TestCmapAllInParallel(t *testing.T) {
	testCases1 := testCases1ForCmapTest
	testCases2 := testCases2ForCmapTest
	concurrency := testCaseNumberForCmapTest / 4
	cm, _ := NewConcurrentMap(concurrency, nil)
	t.Run("All in parallel", func(t *testing.T) {
		t.Run("Put1", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases1 {
				_, err := cm.Put(p.Key(), p.Element())
				if err != nil {
					t.Fatalf("An error occurs when putting a key-element to the cmap: %s (key: %s, element: %#v)",
						err, p.Key(), p.Element())
				}
			}
		})
		t.Run("Put2", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases2 {
				_, err := cm.Put(p.Key(), p.Element())
				if err != nil {
					t.Fatalf("An error occurs when putting a key-element to the cmap: %s (key: %s, element: %#v)",
						err, p.Key(), p.Element())
				}
			}
		})
		t.Run("Get1", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases1 {
				actualElement := cm.Get(p.Key())
				if actualElement == nil {
					continue
				}
				if actualElement != p.Element() {
					t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
						p.Element(), actualElement)
				}
			}
		})
		t.Run("Get2", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases1 {
				actualElement := cm.Get(p.Key())
				if actualElement == nil {
					continue
				}
				if actualElement != p.Element() {
					t.Fatalf("Inconsistent element: expected: %#v, actual: %#v",
						p.Element(), actualElement)
				}
			}
		})
		t.Run("Delete1", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases1 {
				cm.Delete(p.Key())
			}
		})
		t.Run("Delete2", func(t *testing.T) {
			t.Parallel()
			for _, p := range testCases2 {
				cm.Delete(p.Key())
			}
		})
	})
}
