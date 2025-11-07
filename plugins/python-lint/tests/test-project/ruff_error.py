"""Test file with known ruff linting errors."""


def long_function_name_that_will_trigger_line_length_error_because_it_exceeds_the_configured_maximum_line_length_limit():
    """This line is intentionally too long to trigger E501 error."""
    pass


def unused_import_test():
    """Test unused imports."""
    import os  # noqa: F401 - This comment prevents the error, remove it to test

    return "test"


def undefined_name():
    """Test undefined name error."""
    result = undefined_variable_that_does_not_exist  # noqa: F821
    return result
