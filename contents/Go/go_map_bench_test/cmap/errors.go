package cmap

import "fmt"

// IllegalParameterError 代表非法的参数的错误类型。
type IllegalParameterError struct {
	msg string
}

// newIllegalParameterError 会创建一个IllegalParameterError类型的实例。
func newIllegalParameterError(errMsg string) IllegalParameterError {
	return IllegalParameterError{
		msg: fmt.Sprintf("concurrent map: illegal parameter: %s", errMsg),
	}
}

func (ipe IllegalParameterError) Error() string {
	return ipe.msg
}

// IllegalPairTypeError 代表非法的键-元素对类型的错误类型。
type IllegalPairTypeError struct {
	msg string
}

// newIllegalPairTypeError 会创建一个IllegalPairTypeError类型的实例。
func newIllegalPairTypeError(pair Pair) IllegalPairTypeError {
	return IllegalPairTypeError{
		msg: fmt.Sprintf("concurrent map: illegal pair type: %T", pair),
	}
}

func (ipte IllegalPairTypeError) Error() string {
	return ipte.msg
}

// PairRedistributorError 代表无法再分布键-元素对的错误类型。
type PairRedistributorError struct {
	msg string
}

// newPairRedistributorError 会创建一个PairRedistributorError类型的实例。
func newPairRedistributorError(errMsg string) PairRedistributorError {
	return PairRedistributorError{
		msg: fmt.Sprintf("concurrent map: failing pair redistribution: %s", errMsg),
	}
}

func (pre PairRedistributorError) Error() string {
	return pre.msg
}
