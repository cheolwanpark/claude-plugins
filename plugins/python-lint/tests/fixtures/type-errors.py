"""Test file with known pyright type errors."""


def add_numbers(a: int, b: int) -> int:
    """Add two numbers."""
    return a + b


def type_mismatch_test():
    """This will cause a type error."""
    result: int = add_numbers("not", "numbers")  # Type error: str instead of int
    return result


def missing_return_type():
    """Missing return type annotation."""
    x: str = 42  # Type error: int assigned to str
    return x


class TestClass:
    """Test class with type errors."""

    def __init__(self, value: int):
        """Initialize with integer."""
        self.value = value

    def get_value(self) -> str:
        """Return value as string - but actually returns int."""
        return self.value  # Type error: int not compatible with str
