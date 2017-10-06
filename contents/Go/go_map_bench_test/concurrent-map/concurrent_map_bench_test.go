package cmap

import (
	"strconv"
	"sync"
	"testing"
)

// 插入不存在的 key
func BenchmarkSingleInsertAbsent(b *testing.B) {
	m := New()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		m.Set(strconv.Itoa(i), "value")
	}
}

// 插入不存在的 key (syncMap)
func BenchmarkSingleInsertAbsentSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		syncMap.Store(strconv.Itoa(i), "value")
	}
}

// 插入存在 key
func BenchmarkSingleInsertPresent(b *testing.B) {
	m := New()
	m.Set("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		m.Set("key", "value")
	}
}

// 插入存在 key (syncMap)
func BenchmarkSingleInsertPresentSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	syncMap.Store("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		syncMap.Store("key", "value")
	}
}

// 并发的插入不存在的 key-value
func benchmarkMultiInsertDifferent(b *testing.B) {
	m := New()
	finished := make(chan struct{}, b.N)
	_, set := GetSet(m, finished)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		set(strconv.Itoa(i), "value")
	}
	for i := 0; i < b.N; i++ {
		<-finished
	}
}

func BenchmarkMultiInsertDifferent_1_Shard(b *testing.B) {
	runWithShards(benchmarkMultiInsertDifferent, b, 1)
}
func BenchmarkMultiInsertDifferent_16_Shard(b *testing.B) {
	runWithShards(benchmarkMultiInsertDifferent, b, 16)
}
func BenchmarkMultiInsertDifferent_32_Shard(b *testing.B) {
	runWithShards(benchmarkMultiInsertDifferent, b, 32)
}
func BenchmarkMultiInsertDifferent_256_Shard(b *testing.B) {
	runWithShards(benchmarkMultiInsertDifferent, b, 256)
}

// 并发的插入不存在的 key-value (syncMap)
func BenchmarkMultiInsertDifferentSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	finished := make(chan struct{}, b.N)

	set := func(key, value string) {
		for i := 0; i < 10; i++ {
			syncMap.Store(key, value)
		}
		finished <- struct{}{}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		set(strconv.Itoa(i), "value")
	}
	for i := 0; i < b.N; i++ {
		<-finished
	}
}

// 并发的插入相同的 key-value
func BenchmarkMultiInsertSame(b *testing.B) {
	m := New()
	finished := make(chan struct{}, b.N)
	_, set := GetSet(m, finished)
	m.Set("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		set("key", "value")
	}
	for i := 0; i < b.N; i++ {
		<-finished
	}
}

// 并发的插入相同的 key-value (syncMap)
func BenchmarkMultiInsertSameSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	finished := make(chan struct{}, b.N)

	set := func(key, value string) {
		for i := 0; i < 10; i++ {
			syncMap.Store(key, value)
		}
		finished <- struct{}{}
	}
	syncMap.Store("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		set("key", "value")
	}
	for i := 0; i < b.N; i++ {
		<-finished
	}
}

// 并发的 get
func BenchmarkMultiGetSame(b *testing.B) {
	m := New()
	finished := make(chan struct{}, b.N)
	get, _ := GetSet(m, finished)
	m.Set("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		get("key", "value")
	}
	for i := 0; i < b.N; i++ {
		<-finished
	}
}

// 并发的 get (syncMap)
func BenchmarkMultiGetSameSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	finished := make(chan struct{}, b.N)
	get := func(key, value string) {
		for i := 0; i < 10; i++ {
			syncMap.Load(key)
		}
		finished <- struct{}{}
	}
	syncMap.Store("key", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		get("key", "value")
	}
	for i := 0; i < b.N; i++ {
		<-finished
	}
}

// 并发的 get 和 set
func benchmarkMultiGetSetDifferent(b *testing.B) {
	m := New()
	finished := make(chan struct{}, 2*b.N)
	get, set := GetSet(m, finished)
	m.Set("-1", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		set(strconv.Itoa(i-1), "value")
		get(strconv.Itoa(i), "value")
	}
	for i := 0; i < 2*b.N; i++ {
		<-finished
	}
}

func BenchmarkMultiGetSetDifferent_1_Shard(b *testing.B) {
	runWithShards(benchmarkMultiGetSetDifferent, b, 1)
}
func BenchmarkMultiGetSetDifferent_16_Shard(b *testing.B) {
	runWithShards(benchmarkMultiGetSetDifferent, b, 16)
}
func BenchmarkMultiGetSetDifferent_32_Shard(b *testing.B) {
	runWithShards(benchmarkMultiGetSetDifferent, b, 32)
}
func BenchmarkMultiGetSetDifferent_256_Shard(b *testing.B) {
	runWithShards(benchmarkMultiGetSetDifferent, b, 256)
}

// 并发的 get 和 set (syncMap)
func BenchmarkMultiGetSetDifferentSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	finished := make(chan struct{}, 2*b.N)
	get := func(key, value string) {
		for i := 0; i < 10; i++ {
			syncMap.Load(key)
		}
		finished <- struct{}{}
	}
	set := func(key, value string) {
		for i := 0; i < 10; i++ {
			syncMap.Store(key, value)
		}
		finished <- struct{}{}
	}
	syncMap.Store("-1", "value")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		set(strconv.Itoa(i-1), "value")
		get(strconv.Itoa(i), "value")
	}
	for i := 0; i < 2*b.N; i++ {
		<-finished
	}
}

// get set 已经存在的一些 key
func benchmarkMultiGetSetBlock(b *testing.B) {
	m := New()
	finished := make(chan struct{}, 2*b.N)
	get, set := GetSet(m, finished)
	for i := 0; i < b.N; i++ {
		m.Set(strconv.Itoa(i%100), "value")
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		set(strconv.Itoa(i%100), "value")
		get(strconv.Itoa(i%100), "value")
	}
	for i := 0; i < 2*b.N; i++ {
		<-finished
	}
}

func BenchmarkMultiGetSetBlock_1_Shard(b *testing.B) {
	runWithShards(benchmarkMultiGetSetBlock, b, 1)
}
func BenchmarkMultiGetSetBlock_16_Shard(b *testing.B) {
	runWithShards(benchmarkMultiGetSetBlock, b, 16)
}
func BenchmarkMultiGetSetBlock_32_Shard(b *testing.B) {
	runWithShards(benchmarkMultiGetSetBlock, b, 32)
}
func BenchmarkMultiGetSetBlock_256_Shard(b *testing.B) {
	runWithShards(benchmarkMultiGetSetBlock, b, 256)
}

// get set 已经存在的一些 key (syncMap)
func BenchmarkMultiGetSetBlockSyncMap(b *testing.B) {
	syncMap := &sync.Map{}
	finished := make(chan struct{}, 2*b.N)
	get := func(key, value string) {
		for i := 0; i < 10; i++ {
			syncMap.Load(key)
		}
		finished <- struct{}{}
	}
	set := func(key, value string) {
		for i := 0; i < 10; i++ {
			syncMap.Store(key, value)
		}
		finished <- struct{}{}
	}
	for i := 0; i < b.N; i++ {
		syncMap.Store(strconv.Itoa(i%100), "value")
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		set(strconv.Itoa(i%100), "value")
		get(strconv.Itoa(i%100), "value")
	}
	for i := 0; i < 2*b.N; i++ {
		<-finished
	}
}

func GetSet(m ConcurrentMap, finished chan struct{}) (set func(key, value string), get func(key, value string)) {
	return func(key, value string) {
			for i := 0; i < 10; i++ {
				m.Get(key)
			}
			finished <- struct{}{}
		}, func(key, value string) {
			for i := 0; i < 10; i++ {
				m.Set(key, value)
			}
			finished <- struct{}{}
		}
}

func runWithShards(bench func(b *testing.B), b *testing.B, shardsCount int) {
	oldShardsCount := SHARD_COUNT
	SHARD_COUNT = shardsCount
	bench(b)
	SHARD_COUNT = oldShardsCount
}
