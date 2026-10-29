use vstd::prelude::*;

verus! {

pub fn increment(value: u64) -> (result: u64)
    requires value < u64::MAX,
    ensures result == value + 1,
{
    value + 1
}

pub proof fn increment_is_greater(value: int)
    ensures value + 1 > value,
{
}

}
