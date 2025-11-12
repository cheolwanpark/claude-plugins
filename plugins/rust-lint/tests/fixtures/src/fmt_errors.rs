// File with formatting issues for testing rustfmt

pub fn badly_formatted(x:i32,y:i32)->i32{x+y}

pub fn inconsistent_spacing(  a  :  i32  ,  b  :  i32  )  ->  i32  {
    a  +  b
}

pub fn long_line() -> String {
    "This is an extremely long line that exceeds the default line length limit and should be wrapped by rustfmt to improve readability".to_string()
}

pub fn weird_braces()
{
let x=5;let y=10;
x+y
}

pub struct BadlyFormattedStruct{pub field1:i32,pub field2:String,pub field3:bool}
