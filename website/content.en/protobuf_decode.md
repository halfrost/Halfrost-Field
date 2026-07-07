+++
author = "一缕殇流化隐半边冰霜"
categories = ["Protocol buffers", "Protocol"]
date = 2018-05-27T16:44:00Z
description = ""
draft = false
image = "https://img.halfrost.com/Blog/ArticleTitleImage/85_0.png"
slug = "protobuf_decode"
tags = ["Protocol buffers", "Protocol"]
title = "Efficient Data Serialization/Deserialization with Protobuf"

+++


## I. protocol buffers Serialization

The previous article already covered the encoding process. In this article, using Golang as an example, we’ll discuss the serialization and deserialization process from the perspective of the code implementation.

Here is an example of using protobuf in Go for data serialization and deserialization. This article starts with this example.

First, create a new `example` message:
```proto
	syntax = "proto2";
	package example;

	enum FOO { X = 17; };

	message Test {
	  required string label = 1;
	  optional int32 type = 2 [default=77];
	  repeated int64 reps = 3;
	  optional group OptionalGroup = 4 {
	    required string RequiredField = 5;
	  }
	}
```
Use `protoc-gen-go` to generate the corresponding get/set methods. The generated code can then be used in your codebase for serialization and deserialization.
```go
	package main

	import (
		"log"

		"github.com/golang/protobuf/proto"
		"path/to/example"
	)

	func main() {
		test := &example.Test {
			Label: proto.String("hello"),
			Type:  proto.Int32(17),
			Reps:  []int64{1, 2, 3},
			Optionalgroup: &example.Test_OptionalGroup {
				RequiredField: proto.String("good bye"),
			},
		}
		data, err := proto.Marshal(test)
		if err != nil {
			log.Fatal("marshaling error: ", err)
		}
		newTest := &example.Test{}
		err = proto.Unmarshal(data, newTest)
		if err != nil {
			log.Fatal("unmarshaling error: ", err)
		}
		// Now test and newTest contain the same data.
		if test.GetLabel() != newTest.GetLabel() {
			log.Fatalf("data mismatch %q != %q", test.GetLabel(), newTest.GetLabel())
		}
		// etc.
	}
```
In the code above, `proto.Marshal()` is the serialization process, and `proto.Unmarshal()` is the deserialization process. This section first looks at the implementation of the serialization process; the next section will analyze the implementation of the deserialization process.
```go
// Marshal takes the protocol buffer
// and encodes it into the wire format, returning the data.
func Marshal(pb Message) ([]byte, error) {
	// Can the object marshal itself?
	if m, ok := pb.(Marshaler); ok {
		return m.Marshal()
	}
	p := NewBuffer(nil)
	err := p.Marshal(pb)
	if p.buf == nil && err == nil {
		// Return a non-nil slice on success.
		return []byte{}, nil
	}
	return p.buf, err
}
```
When the serialization function is invoked, it first calls the serialization method implemented by the message object itself.
```go
// Marshaler is the interface representing objects that can marshal themselves.
type Marshaler interface {
	Marshal() ([]byte, error)
}
```
`Marshaler` is an interface reserved specifically for objects to customize their own serialization. If it is implemented, the object returns the method it implements. If not, the default serialization process is used next.
```go
	p := NewBuffer(nil)
	err := p.Marshal(pb)
	if p.buf == nil && err == nil {
		// Return a non-nil slice on success.
		return []byte{}, nil
	}
```
Create a new Buffer and call the Buffer's Marshal() method. After the message is serialized, the data stream is placed into the Buffer's buf byte stream. Serialization ultimately just returns the buf byte stream.
```go
type Buffer struct {
	buf   []byte // encode/decode byte stream
	index int    // read point

	// pools of basic types to amortize allocation.
	bools   []bool
	uint32s []uint32
	uint64s []uint64

	// extra pools, only used with pointer_reflect.go
	int32s   []int32
	int64s   []int64
	float32s []float32
	float64s []float64
}
```
The data structure of `Buffer` is shown above. `Buffer` is a buffer manager used for serializing and deserializing protocol buffers. It can be reused across calls to reduce memory usage. Internally, it maintains 7 pools: 3 pools for basic data types and 4 pools that can only be used by `pointer_reflect`.
```go
func (p *Buffer) Marshal(pb Message) error {
	// Can the object marshal itself?
	if m, ok := pb.(Marshaler); ok {
		data, err := m.Marshal()
		p.buf = append(p.buf, data...)
		return err
	}

	t, base, err := getbase(pb)
	// Error handling
	if structPointer_IsNil(base) {
		return ErrNil
	}
	if err == nil {
		err = p.enc_struct(GetProperties(t.Elem()), base)
	}

	// Used to count Encode calls
	if collectStats {
		(stats).Encode++ // Parens are to work around a goimports bug.
	}
	// maxMarshalSize = 1<<31 - 1, this is the maximum value protobuf can encode.
	if len(p.buf) > maxMarshalSize {
		return ErrTooLarge
	}
	return err
}
```
The Buffer’s Marshal() method still first checks whether the object implements the Marshal() interface. If it does, it lets the object serialize itself as before, and then appends the serialized binary data stream to the buf data stream.
```go
func getbase(pb Message) (t reflect.Type, b structPointer, err error) {
	if pb == nil {
		err = ErrNil
		return
	}
	// get the reflect type of the pointer to the struct.
	t = reflect.TypeOf(pb)
	// get the address of the struct.
	value := reflect.ValueOf(pb)
	b = toStructPointer(value)
	return
}
```
The `getbase` method uses reflection to obtain the `message` type and the struct pointer for the corresponding value. After obtaining the struct pointer, it first performs exception handling.

So the core serialization logic is actually just one line: `p.enc\_struct(GetProperties(t.Elem()), base)`
```go
// Encode a struct.
func (o *Buffer) enc_struct(prop *StructProperties, base structPointer) error {
	var state errorState
	// Encode fields in tag order so that decoders may use optimizations
	// that depend on the ordering.
	// https://developers.google.com/protocol-buffers/docs/encoding#order
	for _, i := range prop.order {
		p := prop.Prop[i]
		if p.enc != nil {
			err := p.enc(o, p, base)
			if err != nil {
				if err == ErrNil {
					if p.Required && state.err == nil {
						state.err = &RequiredNotSetError{p.Name}
					}
				} else if err == errRepeatedHasNil {
					// Give more context to nil values in repeated fields.
					return errors.New("repeated field " + p.OrigName + " has nil element")
				} else if !state.shouldContinue(err, p) {
					return err
				}
			}
			if len(o.buf) > maxMarshalSize {
				return ErrTooLarge
			}
		}
	}

	// Do oneof fields.
	if prop.oneofMarshaler != nil {
		m := structPointer_Interface(base, prop.stype).(Message)
		if err := prop.oneofMarshaler(m, o); err == ErrNil {
			return errOneofHasNil
		} else if err != nil {
			return err
		}
	}

	// Add unrecognized fields at the end.
	if prop.unrecField.IsValid() {
		v := *structPointer_Bytes(base, prop.unrecField)
		if len(o.buf)+len(v) > maxMarshalSize {
			return ErrTooLarge
		}
		if len(v) > 0 {
			o.buf = append(o.buf, v...)
		}
	}

	return state.err
}

```
As you can see in the code above, except for oneof fields and unrecognized fields, which are handled separately at the end, all other types are serialized by calling `p.enc(o, p, base)`.

The data structure of Properties is defined as follows:
```go
type Properties struct {
	Name     string // name of the field, for error messages
	OrigName string // original name before protocol compiler (always set)
	JSONName string // name to use for JSON; determined by protoc
	Wire     string
	WireType int
	Tag      int
	Required bool
	Optional bool
	Repeated bool
	Packed   bool   // relevant for repeated primitives only
	Enum     string // set for enum types only
	proto3   bool   // whether this is known to be a proto3 field; set for []byte only
	oneof    bool   // whether this is a oneof field

	Default     string // default value
	HasDefault  bool   // whether an explicit default was provided
	CustomType  string
	StdTime     bool
	StdDuration bool

	enc           encoder
	valEnc        valueEncoder // set for bool and numeric types only
	field         field
	tagcode       []byte // encoding of EncodeVarint((Tag<<3)|WireType)
	tagbuf        [8]byte
	stype         reflect.Type      // set for struct types only
	sstype        reflect.Type      // set for slices of structs types only
	ctype         reflect.Type      // set for custom types only
	sprop         *StructProperties // set for struct types only
	isMarshaler   bool
	isUnmarshaler bool

	mtype    reflect.Type // set for map types only
	mkeyprop *Properties  // set for map types only
	mvalprop *Properties  // set for map types only

	size    sizer
	valSize valueSizer // set for bool and numeric types only

	dec    decoder
	valDec valueDecoder // set for bool and numeric types only

	// If this is a packable field, this will be the decoder for the packed version of the field.
	packedDec decoder
}

```
In the `Properties` struct, an encoder named `enc` and a decoder named `dec` are defined.

The `encoder` and `decoder` function definitions are exactly the same.
```go
type encoder func(p *Buffer, prop *Properties, base structPointer) error
```

```go
type decoder func(p *Buffer, prop *Properties, base structPointer) error

```
The encoder and decoder functions are initialized in Properties:
```go
// Initialize the fields for encoding and decoding.
func (p *Properties) setEncAndDec(typ reflect.Type, f *reflect.StructField, lockGetProp bool) {
	// Code below is abridged; similar parts are omitted
	// proto3 scalar types
	
	case reflect.Int32:
		if p.proto3 {
			p.enc = (*Buffer).enc_proto3_int32
			p.dec = (*Buffer).dec_proto3_int32
			p.size = size_proto3_int32
		} else {
			p.enc = (*Buffer).enc_ref_int32
			p.dec = (*Buffer).dec_proto3_int32
			p.size = size_ref_int32
		}
	case reflect.Uint32:
		if p.proto3 {
			p.enc = (*Buffer).enc_proto3_uint32
			p.dec = (*Buffer).dec_proto3_int32 // can reuse
			p.size = size_proto3_uint32
		} else {
			p.enc = (*Buffer).enc_ref_uint32
			p.dec = (*Buffer).dec_proto3_int32 // can reuse
			p.size = size_ref_uint32
		}
	case reflect.Float32:
		if p.proto3 {
			p.enc = (*Buffer).enc_proto3_uint32 // can just treat them as bits
			p.dec = (*Buffer).dec_proto3_int32
			p.size = size_proto3_uint32
		} else {
			p.enc = (*Buffer).enc_ref_uint32 // can just treat them as bits
			p.dec = (*Buffer).dec_proto3_int32
			p.size = size_ref_uint32
		}
	case reflect.String:
		if p.proto3 {
			p.enc = (*Buffer).enc_proto3_string
			p.dec = (*Buffer).dec_proto3_string
			p.size = size_proto3_string
		} else {
			p.enc = (*Buffer).enc_ref_string
			p.dec = (*Buffer).dec_proto3_string
			p.size = size_ref_string
		}

	case reflect.Slice:
		switch t2 := t1.Elem(); t2.Kind() {
		default:
			logNoSliceEnc(t1, t2)
			break

		case reflect.Int32:
			if p.Packed {
				p.enc = (*Buffer).enc_slice_packed_int32
				p.size = size_slice_packed_int32
			} else {
				p.enc = (*Buffer).enc_slice_int32
				p.size = size_slice_int32
			}
			p.dec = (*Buffer).dec_slice_int32
			p.packedDec = (*Buffer).dec_slice_packed_int32
		
			default:
				logNoSliceEnc(t1, t2)
				break
			}
		}

	case reflect.Map:
		p.enc = (*Buffer).enc_new_map
		p.dec = (*Buffer).dec_new_map
		p.size = size_new_map

		p.mtype = t1
		p.mkeyprop = &Properties{}
		p.mkeyprop.init(reflect.PtrTo(p.mtype.Key()), "Key", f.Tag.Get("protobuf_key"), nil, lockGetProp)
		p.mvalprop = &Properties{}
		vtype := p.mtype.Elem()
		if vtype.Kind() != reflect.Ptr && vtype.Kind() != reflect.Slice {
			// The value type is not a message (*T) or bytes ([]byte),
			// so we need encoders for the pointer to this type.
			vtype = reflect.PtrTo(vtype)
		}

		p.mvalprop.CustomType = p.CustomType
		p.mvalprop.StdDuration = p.StdDuration
		p.mvalprop.StdTime = p.StdTime
		p.mvalprop.init(vtype, "Value", f.Tag.Get("protobuf_val"), nil, lockGetProp)
	}
	p.setTag(lockGetProp)
}

```
In the code above, each type is enumerated using `switch`-`case`. For each case, the corresponding `encode` encoder, `decode` decoder, and `size` are set. The differences between proto2 and proto3 are also handled as two separate cases.

There are 12 broad categories of types: `reflect.Bool`, `reflect.Int32`, `reflect.Uint32`, `reflect.Int64`, `reflect.Uint64`, `reflect.Float32`, `reflect.Float64`, `reflect.String`, `reflect.Struct`, `reflect.Ptr`, `reflect.Slice`, and `reflect.Map`.

Below, we will mainly analyze the code implementations for three categories: `Int32`, `String`, and `Map`.


### 1. Int32
```go
func (o *Buffer) enc_proto3_int32(p *Properties, base structPointer) error {
	v := structPointer_Word32Val(base, p.field)
	x := int32(word32Val_Get(v)) // permit sign extension to use full 64-bit range
	if x == 0 {
		return ErrNil
	}
	o.buf = append(o.buf, p.tagcode...)
	p.valEnc(o, uint64(x))
	return nil
}
```
Handling Int32 is relatively straightforward: first put tagcode into the buf binary data stream buffer, then serialize the Int32 value and place the serialized data into the buffer immediately after tagcode.
```go
// EncodeVarint writes a varint-encoded integer to the Buffer.
// This is the format for the
// int32, int64, uint32, uint64, bool, and enum
// protocol buffer types.
func (p *Buffer) EncodeVarint(x uint64) error {
	for x >= 1<<7 {
		p.buf = append(p.buf, uint8(x&0x7f|0x80))
		x >>= 7
	}
	p.buf = append(p.buf, uint8(x))
	return nil
}
```
The encoding method for Int32 was discussed in the [previous article](https://github.com/halfrost/Halfrost-Field/blob/master/contents/Protocol/Protocol-buffers-encode.md), using the Varint encoding method. The function above is also suitable for handling int32, int64, uint32, uint64, bool, and enum.

While we’re at it, we can also take a look at the concrete code implementations of sint32 and Fixed32.
```go
// EncodeZigzag32 writes a zigzag-encoded 32-bit integer
// to the Buffer.
// This is the format used for the sint32 protocol buffer type.
func (p *Buffer) EncodeZigzag32(x uint64) error {
	// use signed number to get arithmetic right shift.
	return p.EncodeVarint(uint64((uint32(x) << 1) ^ uint32((int32(x) >> 31))))
}
```
For signed `sint32`, the approach is to apply Zigzag encoding first, then process it as a Varint.
```go
// EncodeFixed32 writes a 32-bit integer to the Buffer.
// This is the format for the
// fixed32, sfixed32, and float protocol buffer types.
func (p *Buffer) EncodeFixed32(x uint64) error {
	p.buf = append(p.buf,
		uint8(x),
		uint8(x>>8),
		uint8(x>>16),
		uint8(x>>24))
	return nil
}
```
For `Fixed32`, the handling is merely bit shifting; no compression is performed.

### 2. String
```go
func (o *Buffer) enc_proto3_string(p *Properties, base structPointer) error {
	v := *structPointer_StringVal(base, p.field)
	if v == "" {
		return ErrNil
	}
	o.buf = append(o.buf, p.tagcode...)
	o.EncodeStringBytes(v)
	return nil
}
```
Serializing a string is also split into two steps: first write the tagcode, then serialize the data.
```go
// EncodeStringBytes writes an encoded string to the Buffer.
// This is the format used for the proto2 string type.
func (p *Buffer) EncodeStringBytes(s string) error {
	p.EncodeVarint(uint64(len(s)))
	p.buf = append(p.buf, s...)
	return nil
}
```
When serializing a string, the string’s length is first encoded as a Varint and written to buf. The length is then immediately followed by the string. This is the implementation of tag - length - value.


### 3. Map
```go
// Encode a map field.
func (o *Buffer) enc_new_map(p *Properties, base structPointer) error {
	var state errorState // XXX: or do we need to plumb this through?

	v := structPointer_NewAt(base, p.field, p.mtype).Elem() // map[K]V
	if v.Len() == 0 {
		return nil
	}

	keycopy, valcopy, keybase, valbase := mapEncodeScratch(p.mtype)

	enc := func() error {
		if err := p.mkeyprop.enc(o, p.mkeyprop, keybase); err != nil {
			return err
		}
		if err := p.mvalprop.enc(o, p.mvalprop, valbase); err != nil && err != ErrNil {
			return err
		}
		return nil
	}

	// Don't sort map keys. It is not required by the spec, and C++ doesn't do it.
	for _, key := range v.MapKeys() {
		val := v.MapIndex(key)

		keycopy.Set(key)
		valcopy.Set(val)

		o.buf = append(o.buf, p.tagcode...)
		if err := o.enc_len_thing(enc, &state); err != nil {
			return err
		}
	}
	return nil
}
```
The code above can also serialize an array of dictionaries, for example:
```go
map<key_type, value_type> map_field = N;
```
Convert it into the corresponding `repeated message` form before serialization.
```
message MapFieldEntry {
		key_type key = 1;
		value_type value = 2;
}
repeated MapFieldEntry map_field = N;
```
For map serialization, a tagcode is inserted for each k-v pair before serializing the k-v. When serializing a struct of unknown length here, you need to call the enc\_len\_thing() method.
```go
// Encode something, preceded by its encoded length (as a varint).
func (o *Buffer) enc_len_thing(enc func() error, state *errorState) error {
	iLen := len(o.buf)
	o.buf = append(o.buf, 0, 0, 0, 0) // reserve four bytes for length
	iMsg := len(o.buf)
	err := enc()
	if err != nil && !state.shouldContinue(err, nil) {
		return err
	}
	lMsg := len(o.buf) - iMsg
	lLen := sizeVarint(uint64(lMsg))
	switch x := lLen - (iMsg - iLen); {
	case x > 0: // actual length is x bytes larger than the space we reserved
		// Move msg x bytes right.
		o.buf = append(o.buf, zeroes[:x]...)
		copy(o.buf[iMsg+x:], o.buf[iMsg:iMsg+lMsg])
	case x < 0: // actual length is x bytes smaller than the space we reserved
		// Move msg x bytes left.
		copy(o.buf[iMsg+x:], o.buf[iMsg:iMsg+lMsg])
		o.buf = o.buf[:len(o.buf)+x] // x is negative
	}
	// Encode the length in the reserved space.
	o.buf = o.buf[:iLen]
	o.EncodeVarint(uint64(lMsg))
	o.buf = o.buf[:len(o.buf)+lMsg]
	return state.err
}
```
The `enc_len_thing()` method first reserves 4 bytes as a placeholder for the length. After serialization, it computes the length. If the length requires more than 4 bytes, it shifts the serialized binary data to the right and writes the length between the tagcode and the data. If the length requires fewer than 4 bytes, it shifts the data to the left accordingly.


### 4. slice

Finally, let’s look at an array example. Take []int32 as an example.
```go
// Encode a slice of int32s ([]int32) in packed format.
func (o *Buffer) enc_slice_packed_int32(p *Properties, base structPointer) error {
	s := structPointer_Word32Slice(base, p.field)
	l := s.Len()
	if l == 0 {
		return ErrNil
	}
	// TODO: Reuse a Buffer.
	buf := NewBuffer(nil)
	for i := 0; i < l; i++ {
		x := int32(s.Index(i)) // permit sign extension to use full 64-bit range
		p.valEnc(buf, uint64(x))
	}

	o.buf = append(o.buf, p.tagcode...)
	o.EncodeVarint(uint64(len(buf.buf)))
	o.buf = append(o.buf, buf.buf...)
	return nil
}
```
Serialize this array in three steps: first write the tagcode, then serialize the length of the entire array, and finally serialize each element of the array and append it afterward. The final form is tag - length - value - value - value.

The above is the Protocol Buffer serialization process.

### Serialization Summary:

Protocol Buffer serialization uses Varint and Zigzag to compress `int` integers and signed integers. It does not compress floating-point numbers (there is room for further compression here; Protocol Buffer still has potential for improvement). When encoding a `.proto` file, it checks `option` and `repeated` fields. If an `optional` or `repeated` field has not been assigned a value, that field is completely absent from the serialized data; in other words, it is not serialized (one less field to encode).

The two points above reduce the data size and the amount of serialization work.

The serialization process consists entirely of binary bit shifts, so it is extremely fast. Data exists in the binary data stream in the form tag - length - value (or tag - value). By using a TLV structure to store data, it also eliminates separators such as `{`, `}`, and `;` in JSON. Removing these separators further reduces the amount of data.

This is what makes serialization extremely fast.

## II. protocol buffers Deserialization

The deserialization implementation is exactly the inverse of the serialization implementation.
```go
func Unmarshal(buf []byte, pb Message) error {
	pb.Reset()
	return UnmarshalMerge(buf, pb)
}
```
Reset the buffer before deserialization starts.
```go
func (p *Buffer) Reset() {
	p.buf = p.buf[0:0] // for reading/writing
	p.index = 0        // for reading
}
```
Clear all data in `buf` and reset the index.
```go
func UnmarshalMerge(buf []byte, pb Message) error {
	// If the object can unmarshal itself, let it.
	if u, ok := pb.(Unmarshaler); ok {
		return u.Unmarshal(buf)
	}
	return NewBuffer(buf).Unmarshal(pb)
}
```
Deserialization starts from the function above. If the result of the incoming `message` does not match the result of `buf`, the final outcome is unpredictable. Before deserialization, the corresponding custom `Unmarshal()` method on the object itself is likewise invoked.
```go
type Unmarshaler interface {
	Unmarshal([]byte) error
}
```
`Unmarshal()` is an interface that you can implement yourself.

`UnmarshalMerge` calls the `Unmarshal(pb Message)` method.
```go
func (p *Buffer) Unmarshal(pb Message) error {
	// If the object can unmarshal itself, let it.
	if u, ok := pb.(Unmarshaler); ok {
		err := u.Unmarshal(p.buf[p.index:])
		p.index = len(p.buf)
		return err
	}

	typ, base, err := getbase(pb)
	if err != nil {
		return err
	}

	err = p.unmarshalType(typ.Elem(), GetProperties(typ.Elem()), false, base)

	if collectStats {
		stats.Decode++
	}

	return err
}
```
The `Unmarshal(pb Message)` function has only one input parameter, which differs from the function signature of `proto.Unmarshal()` (the former has 1 input parameter, while the latter has 2). The difference is that the implementation of the single-parameter function does not reset the `buf` buffer, whereas the two-parameter version resets the `buf` buffer first.

Both functions ultimately call the `unmarshalType()` method, which is the function that actually supports deserialization.
```go
func (o *Buffer) unmarshalType(st reflect.Type, prop *StructProperties, is_group bool, base structPointer) error {
	var state errorState
	required, reqFields := prop.reqCount, uint64(0)

	var err error
	for err == nil && o.index < len(o.buf) {
		oi := o.index
		var u uint64
		u, err = o.DecodeVarint()
		if err != nil {
			break
		}
		wire := int(u & 0x7)
		
		// Code omitted below
		
		dec := p.dec
		
		// Code omitted in the middle
		
		decErr := dec(o, p, base)
		if decErr != nil && !state.shouldContinue(decErr, p) {
			err = decErr
		}
		if err == nil && p.Required {
			// Successfully decoded a required field.
			if tag <= 64 {
				// use bitmap for fields 1-64 to catch field reuse.
				var mask uint64 = 1 << uint64(tag-1)
				if reqFields&mask == 0 {
					// new required field
					reqFields |= mask
					required--
				}
			} else {
				// This is imprecise. It can be fooled by a required field
				// with a tag > 64 that is encoded twice; that's very rare.
				// A fully correct implementation would require allocating
				// a data structure, which we would like to avoid.
				required--
			}
		}
	}
	if err == nil {
		if is_group {
			return io.ErrUnexpectedEOF
		}
		if state.err != nil {
			return state.err
		}
		if required > 0 {
			// Not enough information to determine the exact field. If we use extra
			// CPU, we could determine the field only if the missing required field
			// has a tag <= 64 and we check reqFields.
			return &RequiredNotSetError{"{Unknown}"}
		}
	}
	return err
}
```
The `unmarshalType()` function is fairly long and handles many cases, including `oneof` and `WireEndGroup`. The function that actually performs deserialization is invoked on this line: `decErr := dec(o, p, base)`.

The `dec` function is initialized in the `setEncAndDec()` function of `Properties`. We discussed that function earlier when covering serialization, so we will not repeat the details here. The `dec()` function has a corresponding deserialization function for each different type.

Similarly, next we will look at four examples to examine the actual implementation of the deserialization code.


### 1. Int32
```go
func (o *Buffer) dec_proto3_int32(p *Properties, base structPointer) error {
	u, err := p.valDec(o)
	if err != nil {
		return err
	}
	word32Val_Set(structPointer_Word32Val(base, p.field), uint32(u))
	return nil
}
```
Deserializing the Int32 code is relatively straightforward. The principle is to reconstruct the original data by following the reverse process of encoding.
```go
func (p *Buffer) DecodeVarint() (x uint64, err error) {
	i := p.index
	buf := p.buf

	if i >= len(buf) {
		return 0, io.ErrUnexpectedEOF
	} else if buf[i] < 0x80 {
		p.index++
		return uint64(buf[i]), nil
	} else if len(buf)-i < 10 {
		return p.decodeVarintSlow()
	}

	var b uint64
	// we already checked the first byte
	x = uint64(buf[i]) - 0x80
	i++

	b = uint64(buf[i])
	i++
	x += b << 7
	if b&0x80 == 0 {
		goto done
	}
	x -= 0x80 << 7

	b = uint64(buf[i])
	i++
	x += b << 14
	if b&0x80 == 0 {
		goto done
	}
	x -= 0x80 << 14

	b = uint64(buf[i])
	i++
	x += b << 21
	if b&0x80 == 0 {
		goto done
	}
	x -= 0x80 << 21

	b = uint64(buf[i])
	i++
	x += b << 28
	if b&0x80 == 0 {
		goto done
	}
	x -= 0x80 << 28

	b = uint64(buf[i])
	i++
	x += b << 35
	if b&0x80 == 0 {
		goto done
	}
	x -= 0x80 << 35

	b = uint64(buf[i])
	i++
	x += b << 42
	if b&0x80 == 0 {
		goto done
	}
	x -= 0x80 << 42

	b = uint64(buf[i])
	i++
	x += b << 49
	if b&0x80 == 0 {
		goto done
	}
	x -= 0x80 << 49

	b = uint64(buf[i])
	i++
	x += b << 56
	if b&0x80 == 0 {
		goto done
	}
	x -= 0x80 << 56

	b = uint64(buf[i])
	i++
	x += b << 63
	if b&0x80 == 0 {
		goto done
	}
	// x -= 0x80 << 63 // Always zero.

	return 0, errOverflow

done:
	p.index = i
	return x, nil
}
```
After an Int32 is serialized, the first byte must be `0x80`. Once that byte is removed, each subsequent binary byte is data. The remaining step is to add up each number through bit-shift operations. The deserialization function above also applies to `int32`, `int64`, `uint32`, `uint64`, `bool`, and `enum`.

While we’re at it, we can also look at the concrete deserialization implementations for `sint32` and `Fixed32`.
```go
func (p *Buffer) DecodeZigzag32() (x uint64, err error) {
	x, err = p.DecodeVarint()
	if err != nil {
		return
	}
	x = uint64((uint32(x) >> 1) ^ uint32((int32(x&1)<<31)>>31))
	return
}
```
For signed sint32, deserialization first decodes the Varint, then applies Zigzag decoding.
```go
func (p *Buffer) DecodeFixed32() (x uint64, err error) {
	// x, err already 0
	i := p.index + 4
	if i < 0 || i > len(p.buf) {
		err = io.ErrUnexpectedEOF
		return
	}
	p.index = i

	x = uint64(p.buf[i-4])
	x |= uint64(p.buf[i-3]) << 8
	x |= uint64(p.buf[i-2]) << 16
	x |= uint64(p.buf[i-1]) << 24
	return
}
```
The `Fixed32` deserialization process also uses bit shifting: by accumulating the contents of each byte, the original data can be reconstructed. Note that the tag position must also be skipped first here.

### 2. String
```go
func (p *Buffer) DecodeRawBytes(alloc bool) (buf []byte, err error) {
	n, err := p.DecodeVarint()
	if err != nil {
		return nil, err
	}

	nb := int(n)
	if nb < 0 {
		return nil, fmt.Errorf("proto: bad byte length %d", nb)
	}
	end := p.index + nb
	if end < p.index || end > len(p.buf) {
		return nil, io.ErrUnexpectedEOF
	}

	if !alloc {
		// todo: check if can get more uses of alloc=false
		buf = p.buf[p.index:end]
		p.index += nb
		return
	}

	buf = make([]byte, nb)
	copy(buf, p.buf[p.index:])
	p.index += nb
	return
}
```
To deserialize a string, first deserialize its length using DecodeVarint. Once you have the length, the rest is just a direct copy. In the previous article on encode, we saw that strings are not processed; they are placed directly into the binary stream, so deserialization simply extracts them.

### 3. Map
```go
func (o *Buffer) dec_new_map(p *Properties, base structPointer) error {
	raw, err := o.DecodeRawBytes(false)
	if err != nil {
		return err
	}
	oi := o.index       // index at the end of this map entry
	o.index -= len(raw) // move buffer back to start of map entry

	mptr := structPointer_NewAt(base, p.field, p.mtype) // *map[K]V
	if mptr.Elem().IsNil() {
		mptr.Elem().Set(reflect.MakeMap(mptr.Type().Elem()))
	}
	v := mptr.Elem() // map[K]V

	// Some code is omitted here, mainly placeholders for key - value that can be double-indirected; for details, see the enc_new_map function in the serialization code

	// Decode.
	// This parses a restricted wire format, namely the encoding of a message
	// with two fields. See enc_new_map for the format.
	for o.index < oi {
		// tagcode for key and value properties are always a single byte
		// because they have tags 1 and 2.
		tagcode := o.buf[o.index]
		o.index++
		switch tagcode {
		case p.mkeyprop.tagcode[0]:
			if err := p.mkeyprop.dec(o, p.mkeyprop, keybase); err != nil {
				return err
			}
		case p.mvalprop.tagcode[0]:
			if err := p.mvalprop.dec(o, p.mvalprop, valbase); err != nil {
				return err
			}
		default:
			// TODO: Should we silently skip this instead?
			return fmt.Errorf("proto: bad map data tag %d", raw[0])
		}
	}
	keyelem, valelem := keyptr.Elem(), valptr.Elem()
	if !keyelem.IsValid() {
		keyelem = reflect.Zero(p.mtype.Key())
	}
	if !valelem.IsValid() {
		valelem = reflect.Zero(p.mtype.Elem())
	}

	v.SetMapIndex(keyelem, valelem)
	return nil
}
```
Deserializing a map requires extracting each tag, then immediately deserializing each key-value pair. Finally, it checks whether `keyelem` and `valelem` are zero values; if they are, `reflect.Zero` is called respectively to handle the zero-value cases.

### 4. slice

Finally, here is another array example, using `[]int32` as an example.
```go
func (o *Buffer) dec_slice_packed_int32(p *Properties, base structPointer) error {
	v := structPointer_Word32Slice(base, p.field)

	nn, err := o.DecodeVarint()
	if err != nil {
		return err
	}
	nb := int(nn) // number of bytes of encoded int32s

	fin := o.index + nb
	if fin < o.index {
		return errOverflow
	}
	for o.index < fin {
		u, err := p.valDec(o)
		if err != nil {
			return err
		}
		v.Append(uint32(u))
	}
	return nil
}
```
Deserialize this array in two steps: skip the tagcode to obtain the length, then deserialize the length. Within that length, deserialize each value in sequence.

The above is the Protocol Buffer deserialization process.

### Deserialization summary:

Protocol Buffer deserialization directly reads the binary byte stream. Deserialization is the inverse of encoding, and likewise consists of binary operations. During deserialization, you typically only need the length. The tag value is only used to identify the type. The `setEncAndDec()` method in `Properties` has already initialized the corresponding decode decoder for each type, so during deserialization, the tag value can be skipped and processing can start from the length.

XML parsing is more complicated. XML needs to read strings from a file and then convert them into an XML document object model. After that, it reads the string of a specified node from the XML document object model, and finally converts that string into a variable of the specified type. This process is very complex; in particular, converting an XML file into a document object model usually requires a large amount of CPU-intensive computation such as lexical and syntactic analysis.


## III. Serialization / Deserialization Performance

Protocol Buffer has long been regarded as a high-performance solution. Many people have implemented benchmarks to verify this claim, such as the experiments in this link: [jvm-serializers](https://github.com/eishay/jvm-serializers/wiki).

Before looking at the data, we can first rationally analyze what advantages Protocol Buffer has over JSON, XML, and similar formats:

1. Protobuf uses Varint and Zigzag to significantly compress integer types, and it does not have data separators such as {, }, and ; like JSON. For fields marked as optional, when there is no data, deserialization is not performed. These measures make the overall data size of pb much smaller than JSON.
2. Protobuf uses a TLV format, while JSON and similar formats are string-based. String comparison should be more time-consuming than numeric field tags. Protobuf has a size or length marker before the payload, whereas JSON must scan the entire document and cannot skip fields that are not needed.

The following figure comes from the reference link “Is Protobuf 5x Faster than JSON? Debunking the pb Performance Myth with Code”:


![](https://img.halfrost.com/Blog/ArticleImage/85_1.png)

From this experiment, Protobuf is indeed extremely strong in terms of performance when serializing numbers.

Serializing / deserializing numbers is indeed where Protobuf has an advantage over JSON and XML, but there are also areas where it does not have an advantage. For example, strings. Strings are basically not processed in Protobuf, except that a tag - length is added in front. In the process of serializing / deserializing strings, the speed of string copying instead determines the actual speed.

![](https://img.halfrost.com/Blog/ArticleImage/85_2.png)


As shown in the figure above, when encoding strings, the speed is basically not much different from JSON.

## III. Conclusion

At this point, readers should have a clear understanding of everything about protocol buffers.

protocol buffers were not originally created for data transmission. They were intended to solve the problem of multi-version protocol compatibility on servers. In essence, they invented a new cross-language, unambiguous IDL (Interface description language). It was only later that people discovered they were also good for transmitting data, and started using protocol buffers for that purpose.

If you want to replace JSON with protocol buffers, the considerations may be:

1. For the same data, protocol buffers transmit less data than JSON. After compression with gzip or 7zip, the network transmission cost is lower.
2. protocol buffers are not self-describing. Without the `.proto` file, they provide a certain degree of obfuscation; data is transmitted as a binary stream rather than plaintext.
3. protocol buffers provide a set of tools, making it very convenient to automatically generate code.
4. protocol buffers are backward compatible. After changing the data structure, older versions are not affected.
5. protocol buffers are natively and perfectly compatible with RPC calls.


If integer numbers and floating-point numbers are rarely used and all the data is string data, then the performance difference between JSON and protocol buffers will not be very large. For interactions purely between front-end components, choosing JSON or protocol buffers does not make a big difference.

When interacting with the backend, protocol buffers are used more often. In the author’s opinion, besides strong performance, perfect compatibility with RPC calls is also an important factor in choosing protocol buffers.

------------------------------------------------------

References:  

[Google official documentation](https://developers.google.com/protocol-buffers/docs/overview)      
[thrift-protobuf-compare - Benchmarking.wiki](https://code.google.com/archive/p/thrift-protobuf-compare/wikis/Benchmarking.wiki)    
[jvm-serializers](https://github.com/eishay/jvm-serializers/wiki)  
[Is Protobuf 5x Faster than JSON? Debunking the pb Performance Myth with Code](https://mp.weixin.qq.com/s?__biz=MzA3NDcyMTQyNQ==&mid=2649257430&idx=1&sn=975b6123d8256221f6bac3b99e52af9a&chksm=8767a428b0102d3e6ab7abdf797c481da570cb29e274aa4ff6ecd931f535166b776e6548941d&scene=0&key=399a205ce674169cbedcc1c459650908e22d6a2b81674195c3b251114acdf821dbde7bb49102c6b47f61b26a7a404d74e0e8440cea3675a7ea8f49eafd8639bfb733183a1bfb4603232d6cb8ecd230e5&ascene=0&uin=NTkxMDk2NjU=&devicetype=iMac+MacBookPro12,1+OSX+OSX+10.12.4+build(16E195)&version=12020510&nettype=WIFI&fontScale=100&pass_ticket=wHPj0w18CV8zHl6HCfd9t9LQfs3I0ZULhUILuOHgL0E=)

> GitHub Repo: [Halfrost-Field](https://github.com/halfrost/Halfrost-Field)
> 
> Follow: [halfrost · GitHub](https://github.com/halfrost)
>
> Source: [https://halfrost.com/protobuf\_decode/](https://halfrost.com/protobuf_decode/)