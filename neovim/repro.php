<?php
global $g;
$GLOBALS['g'] = 1;
const bad_CONST = 1;
define('another_bad', 2);
function Bad_Func() {}
class MyClass {}
for ($i = 0; $i < count($a); $i++) {}
if ($a == $b) {}
$x = $$y;
class CTest {
    var $old;
    public function __construct(public $prop) {}
}
$obj = new CTest;
