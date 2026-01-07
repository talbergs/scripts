# PHP coding guidelines

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in [RFC
2119](http://tools.ietf.org/html/rfc2119).

### General

-   All code and comments MUST be written in English.
-   Global variables MUST NOT be used.
-   `.htaccess` files only define settings for the current directory.
    This is done to avoid the possibility of missing a change for this
    file if some sub-directory is renamed.
-   Zabbix API methods MUST be used instead of writing direct SQL
    queries to database.

#### Files

-   In PHP files **one opening** `<?php` tag MUST exist at the first
    line of the file.
-   The closing `?>` tag MUST be omitted from files containing only PHP.
-   All PHP files MUST use only UTF-8 without BOM for PHP code.
-   All PHP files MUST use the Unix LF (linefeed) line ending only.
-   All PHP files MUST end with a non-blank line, terminated with a
    single LF.

#### Lines

-   Lines MUST NOT be longer than **120** characters; lines longer than
    that MUST be split into multiple subsequent lines of no more than
    120 characters each with two exceptions:
    -   Validation rules MUST always be written on one line.
    -   Translation strings MUST always be written on one line.
-   There MUST NOT be trailing whitespace at the end of lines.
-   Blank lines MAY be added to improve readability and to indicate
    related blocks of code except where explicitly forbidden.
-   There MUST NOT be more than one statement per line.

#### Indenting

-   Code MUST use an indent of one **tab** for each indent level, and
    MUST NOT use spaces for indenting.

#### Declare, namespace and import statements

The header of a PHP file may consist of a number of different blocks. If
present, each of the blocks below MUST be separated by a single blank
line, and MUST NOT contain a blank line. Each block MUST be in the order
listed below, although blocks that are not relevant may be omitted.

-   Opening `<?php` tag with declare statement
    `declare(strict_types = 0);`. (starting from 5.0)
-   Copyright comment.
-   The namespace declaration of the file.
-   One or more `use` import statements.
-   The remainder of the code in the file.

When a file contains a mix of HTML and PHP, any of the above sections
may still be used. If so, they MUST be present at the top of the file,
even if the remainder of the code consists of a closing PHP tag and then
a mixture of HTML and PHP.

The following example illustrates a complete list of all blocks:

```php
<?php declare(strict_types = 0);
/*
** Zabbix
** Copyright (C) 2001-2020 Zabbix SIA
**
** This program is free software; you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation; either version 2 of the License, or
** (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software
** Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
**/


namespace Vendor\Package;

use Vendor\Package\{ClassA as A, ClassB, ClassC as C};
use Vendor\Package\SomeNamespace\ClassD as D;
use Vendor\Package\AnotherNamespace\ClassE as E;

/**
 * CExampleClass is an example class.
 */
class CExampleClass {

    // some logic here
}

```

#### Keywords and types

-   All PHP reserved
    [keywords](http://php.net/manual/en/reserved.keywords.php) and
    [types](http://php.net/manual/en/reserved.other-reserved-words.php)
    MUST be in lower case.
-   Any new types and keywords added to future PHP versions MUST be in
    lower case.
-   Short form of type keywords MUST be used i.e. bool instead of
    boolean, int instead of integer, etc.

#### Directory hierarchy

-   All classes SHOULD be placed under **classes** directory.
-   If there is a bunch of classes that are related to one
    functionality, they SHOULD be placed in a sub-directory.

Example:

    /frontends/php/include/classes/export/CExport.php

    /frontends/php/include/classes/export/writers/CWriter.php
    /frontends/php/include/classes/export/writers/CXmlWriter.php
    /frontends/php/include/classes/export/writers/CJsonWriter.php

    /frontends/php/include/classes/export/exportelements/CExportElement.php
    /frontends/php/include/classes/export/exportelements/CHostExportElement.php
    /frontends/php/include/classes/export/exportelements/CItemExportElement.php

#### Define locations

-   Global defines are located in
    `/frontends/php/include/defines.inc.php`.
-   Translatable defines are located in
    `/frontends/php/include/translateDefines.inc.php`.

### MVC

#### Directory hierarchy in MVC

-   MVC files are located in `/frontends/php/app/` directory.

Example:

    // controller
    /frontends/php/app/controllers/CControllerExample.php

    // view
    /frontends/php/app/views/example.php

    // partial 
    /frontends/php/app/partials/example.php

    // JavaScript file used in the view
    /frontends/php/app/views/js/example.js.php

    // JavaScript file used in the partial
    /frontends/php/app/partials/js/example.js.php

#### MVC controllers

-   By default controllers are performing SID validation.
    -   It is possible to disable it with `disableSIDValidation()` method for pages that we expect to be accessed by direct link.
    -   We MUST make sure SID validation remains enabled for:
        - any controllers that make changes;
        - any controllers that are intended for internal use only.

```php
protected function init(): void {
    $this->disableSIDValidation();
}
```

#### MVC views and partials

Each MVC view and partial files must contain the following PHPDoc
comment below the copyright comment, leaving two empty lines above the
comment and one empty line after.

For MVC view files:

```php
/**
 * @var CView $this
 * @var array $data
 */
```

For MVC partial files:

```php
/**
 * @var CPartial $this
 * @var array    $data
 */
```

### Naming conventions

#### Variables

-   Variable names SHOULD be self-describing, short as possible, but
    still readable.
-   Variables SHOULD contain only lowercase letters. Numbers are
    permitted in variable names but are discouraged in most cases.
-   Each word SHOULD be separated by an underscore.

Example:

```php
// correct
$hostid = 12345;
$item_applications = [];
$db_application_prototypes = [];

// wrong
$hostId = 12345;
$host_id = 12345;
$itemApplications = [];
$dbapplication_prototypes = [];
```

#### Defines and constants

-   Names representing constants (final variables) MUST be all uppercase
    using underscore to separate words.

Example:

```php
// global define
define('ZBX_DB_MYSQL', 'MYSQL');

// translatable define
define('DATE_FORMAT', _('Y-m-d'));

// constant in class
const STATE_NEW = 0;
```

#### Functions and methods

-   Visibility MUST be declared on all methods.
-   Method names MUST NOT be prefixed with a single underscore to
    indicate protected or private visibility.
-   Function and method names MUST always start with a lowercase letter.
    When a function or method name consists of more than one word, the
    first letter of each new word MUST be capitalized (camelCase).
-   Method and function names MUST NOT be declared with space after the
    method name. There MUST NOT be a space after the opening
    parenthesis, and there MUST NOT be a space before the closing
    parenthesis.

Example:

```php
// correct
function create() {
    // some logic here
}

function getName() {
    // some logic here
}

// wrong
function Create() {
    // some logic here
}

function get_name() {
    // some logic here
}
```

-   Abbreviations and acronyms SHOULD NOT be uppercase when used as a
    name.

Example:

```php
// correct
function exportHtmlSource() {
    // some logic here
}

// wrong
function exportHTMLSource() {
    // some logic here
}
```

#### Classes

-   The term "class" refers to all classes, interfaces, and traits.
-   All Zabbix class names MUST start with a "C" prefix and be written
    in CUpperCamelCase. The "C" prefix serves as a historical
    alternative to namespaces.
-   If a class extends another class, child class name SHOULD be
    prefixed to parent class name.

Example:

```php
class CWriter {
    // some logic here
}

class CXmlWriter extends CWriter {
    // some logic here
}

class CFastXmlWriter extends CXmlWriter {
    // some logic here
}
```

#### Filenames

-   Spaces in filenames are strictly prohibited.
-   Include and view file names are written in lowercase letters.
-   View file name represents the menu sections and actions separated by
    dots.

Example:

```php
// Administration → Media type → Edit
administration.mediatype.edit.php
```

-   Class file naming SHOULD be named as the class name (starting with
    capital "[118;1:3uC") with ".php" extension.

Example:

```php
class CWriter {} → CWriter.php
class CXmlWriter {} → CXmlWriter.php
```

-   MVC controller class file names SHOULD be prefixed with "Controller"
    name.

Example:

```php
class CControllerProxyEdit {} → CControllerProxyEdit.php
```

### Variables

#### Variable declaration

-   Each variable MUST be declared on a separate line.

Example:

```php
// correct
$itemids = [];
$hostids = [];

// wrong
$itemids = $hostids = [];
```

-   Arrays MUST be declared using the `[]` shorthand.

```php
// correct
$itemids = [];

// wrong
$itemids = array();
```

-   When instantiating a new class, parentheses MUST always be present
    even when there are no arguments passed to the constructor.

```php
$relation_map = new CRelationMap();
```

-   Closing parenthesis SHOULD be on a new line.

```php
// correct
$another_filter_set = ($filter['select'] !== '' || $filter['application'] !== '' || $filter['groupids']
    || $filter['hostids']
);

// wrong
$another_filter_set = ($filter['select'] !== '' || $filter['application'] !== '' || $filter['groupids']
    || $filter['hostids']);
```

-   [Variable
    variables](https://www.php.net/manual/en/language.variables.variable.php)
    SHOULD NOT be used.
-   *Variable variables* can only be used if the following criteria are
    met:
    -   the resulting static variables are used in the function and are
        reasonable;
    -   usage of variable variables simplifies the code better than
        other methods.

```php
// correct
$array = [];
foreach ($array as $key => $value) {
    $array[$key] = convert($value);
}
foreach (array_keys($array) as $key) {
    do_some_action($array[$key]);
}

// correct
$variable1 = 'value1';
$variable2 = 'value2';
foreach (['variable1', 'variable2'] as $variable) {
    $$variable = convert($$variable);
}

// wrong
foreach ($array as $key => $value) {
    $$key = convert($value);
}
foreach (array_keys($array) as $key) {
    do_some_action($$key);
}
```

#### Superglobal variables

See php.net for a list of [superglobal
variables](http://php.net/manual/en/language.variables.superglobals.php).

- Superglobal variables SHOULD never be modified during script execution.
- `$_REQUEST` values SHOULD NOT be accessed directly. For newer MVC controllers (located in the /ui/app/controllers
folder) dedicated methods `hasInput()`, `getInput()`, etc. SHOULD be used instead. For older controllers
(located directly in the /ui folder) dedicated functions like `hasRequest()`, `getRequest()` SHOULD be used instead.

Example:

```php
// correct (for newer MVC controllers)
if ($this->hasInput('name')) {
    echo $this->getInput('name');
}

// correct (for older controllers)
if (hasRequest('name')) {
    echo getRequest('name');
}

// wrong
if (isset($_REQUEST['name'])) {
   echo $_REQUEST['name'];
}
```

#### Variables in SQL queries

- Variables in SQL queries MUST be escaped using `zbx_dbstr()` function, regardless of value origin.
- To add equality condition of a field to known array of values, `dbConditionString()`, `dbConditionInt()` or 
`dbConditionId()` functions SHOULD be used, depending on database field type. These functions will take care of
correctly escaping values.

Example:

```php
DBselect('SELECT c.actionid FROM conditions c WHERE '.dbConditionString('c.value', $values));
DBselect('SELECT oh.operationid FROM opcommand_hst oh WHERE '.dbConditionId('oh.hostid', $hostids));
```

-   Constants MUST NOT be processed by `zbx_dbstr()`.

Example:

```php
// correct
DBselect('SELECT r.rightid FROM rights r WHERE r.permission>'.PERM_DENY);

// wrong
DBselect('SELECT r.rightid FROM rights r WHERE r.permission>'.zbx_dbstr(PERM_DENY));
```

#### Pre-processing of variables for use in views

All logic related to data visualization SHOULD be part of the view. No
pre-processing aimed to simplify views is allowed in controllers.

Note that this restriction does not apply to situations when we really
need to perform complex calculations in the controller and pass the
result of the calculation to a view.

Example:

```php
// correct
// controller
$data["host"]["status"] = $host["status"];

// view
if ($data["host"]["status"] == HOST_STATUS_MONITORED) {
    // some logic here
}

// wrong
// controller
$data["isHostEnabled"] = ($host["status"] == HOST_STATUS_MONITORED);

// view
if ($data["isHostEnabled"]) {
    // some logic here
}
```

-   Views MUST use variable `$data` instead of class variable `$this->data`.

Example:

```php
// correct
if ($data['groups']) {
    // some logic here
}

// wrong
if ($this->data['groups']) {
    // some logic here
}
```

-   Views MUST NOT use API calls and SQL queries.

### Conditional statements

-   The opening brace MUST be on the same line as the conditional
    statement.
-   The closing brace MUST be on the next line after the body.

Example:

```php
// correct
if (hasRequest('add')) {
    // some logic here
}

// wrong
if (hasRequest('add'))
{
    // some logic here
}
```

#### if, elseif, else

-   `if` statements MUST always use curly braces `{}`.

Example:

```php
// correct
if (hasRequest('add')) {
    $action = 'add';
}

// wrong
if (hasRequest('add'))
    $action = 'add';
```

-   For `if` statements that include `elseif` or `else`, the formatting
    conventions are similar to the `if` construct.

Example:

```php
// correct
if (hasRequest('add')) {
    // some logic here
}
 
if (hasRequest('add')) {
    // some logic here
}
else {
    // some logic here
}

// correct
if (hasRequest('add')) {
    // some logic here
}
elseif (hasRequest('update')) {
    // some logic here
}
else {
    // some logic here
}

// wrong
if (hasRequest('add')) {
    // some logic here
} else {
    // some logic here
}
```

-   For `if` statements that include `elseif`, the `elseif` is written as one word.

```php
// correct
if (hasRequest('add')) {
    // some logic here
}
elseif (hasRequest('update')) {
    // some logic here
}

// wrong
if (hasRequest('add')) {
    // some logic here
}
else if (hasRequest('update')) {
    // some logic here
}
```

-   Inline assignments are only allowed if the variables are only used within the statement body.

Example:

```php
if (($messages = getMessages($result, $msg_title)) !== null) {
    $output['messages'] = $messages->toString();
}
```

-   If the conditional statement causes the line length to exceed the
    maximum line length, conditions are broken into multiple lines using
    two tabs.

Example:

```php
if ($long_expression1 == $very_long_expression2
        || $long_expression2 == $very_long_expression2) {
    // some logic here
}

if ($long_expression1 == $very_long_expression2
        && $long_expression2 == $very_long_expression2
        && $long_expression3 == $very_long_expression3) {
    // some logic here
}
```

-   First conditional statement is indented by two tabs, but inner
    statements are indented by one tab.

Example:

```php
if (($expression1 == $expression2 && $expression3 == $expression4)
        || ($expression5 == $expression6
            && $expression7 == $expression8)
        || $expression9 == $expression10) {
    // some logic here
}
```

#### Ternary operator

-   The conditional operator, also known as the ternary operator, MUST
    be preceded and followed by at least one space around both the `?`
    and `:` characters.

Example:

```php
$name = $expression1 == $expression2 ? 'a' : 'b';

$name = array_key_exists('name_expanded', $items) ? $items['name_expanded'] : $items['name'];
```

-   Left-hand operator can only be omitted for array condition types. In such case `?:` characters MUST be written
together.

Example:

```php
// correct
$array = $input_array ?: $default;

// wrong
$int = $input_int ?: $default;
$string = $input_string ?: $default;
```

- If a statement exceeds maximum line length, it MUST be split to separate lines.

Example:

```php
$name = ($long_expression1 == $very_long_expression1 || $long_expression2 == $very_long_expression2)
    ? 'a'
    : 'b';
```

#### Null coalescing operator

- Usage of null coalescing operator `??` is prohibited.

#### switch, case

-   `break;` can be omitted only for the default case.

Smaller switch example:

```php
switch ($type) {
    case 1:
        // line 1
        break;
    case 2:
        // line 1
        break;
    default:
        // line 1
}
```

Larger switch example:

```php
switch ($type) {
    case 1:
        // line 1
        // line 2
        // line 3
        break;

    case 2:
        // line 1
        // line 2
        // line 3
        break;

    default:
        // line 1
        // line 2
        // line 3
}
```

-   If there's a case label followed by code that falls through to
    another case label, comment MUST be present, confirming that it's
    intentional.

Example:

```php
switch ($type) {
    case 1:
        // line 1
        // break; is not missing here
    case 2:
    case 3:
        // line 1
        break;
    default:
        // line 1
        // line 2
}
```

-   Curly braces are not used for `case` blocks.
-   `break;` MUST use one indentation.

Example:

```php
// correct
switch ($type) {
    case 1:
        // line 1
        break;
    case 2:
        // line 1
        break;
    default:
        // line 1
}

// wrong
switch ($type) {
    case 1:
        // line 1
    break;
    case 2: {
        // line 1
    }
    break;
    default:
        // line 1
}
```

#### try, catch, finally

Example:

```php
try {
    DB::insert('auditlog', [$values]);
    return true;
}
catch (DBException $e) {
    // catch body
}
finally {
    // finally body
}
```

### Comparison

-   Strict comparison MUST always be used for comparing strings.

Example:

```php
// correct
if ($string1 === $string2) {
    // some logic here
}

// wrong
if ($string1 == $string2) {
    // some logic here
}
```

-   Strict comparison MUST be used only when there is a reason to use it.

Example:

```php
// correct - preg_match() method can return integer 0 or 1, or "false".
if (preg_match(...) === 0) {
    // some logic here
}

// wrong - both variables contains integers. There is no need for strict comparison.
if ($length1 === $length2) {
    // some logic here
}
```

-   The "Equal" or "Not equal" operators MUST be used to compare numeric
    values to zero.

Example:

```php
// correct
if ($itemid != 0) {}

// wrong
if ($itemid) {}
```

-   Implicitly nullable parameters are not allowed.

Example:

```php
// correct
function (?int $itemid = null) {}

// correct
function (null|int $itemid = null) {}

// wrong
function (int $itemid = null) {}
```

-   To check an expression against null, the "Identical" operator MUST
    be used instead of the `'is_null()`' function.
-   Nullsafe operator is not allowed. Make sure to check for null explicitly.

Example:

```php
// correct
if ($var === null) {
    // some logic here
}

// correct
$form = $this->hasForm() ? $this->getForm()->toString() : null;

// wrong
if (is_null($var)) {
    // some logic here
}

// wrong
$form = $this->getForm()?->toString();
```

-   For database ID comparison and large integers, **bclib** functions
    SHOULD be used. This will also normalize the IDs before the comparison (remove leading zeros).

Example:

```php
// correct
if (bccomp($data['proxyid'], $host['proxy_hostid']) == 0) {
    // some logic here
}

// wrong
if ($data['proxyid'] == $host['proxy_hostid']) {
    // some logic here
}
```

-   Function `empty()` MUST NOT be used.

Example:

```php
if ($i == 0) {
    // some logic here
}

if ($string === '') {
    // some logic here
}

if ($array) {
    // some logic here
}
```

### Loops

#### for

Example:

```php
// single variable
for ($i = 0; $i < $weeks; $i++) {
    $period_start = $start + SEC_PER_WEEK * $i;
}

// multiple variables
for ($x = $x1, $y = $y1; $x <= $x2; $x++, $y = $y1 + ($x - $x1) * $dy / $dx) {
    // some logic here
}
```

-   Calling `count()` in a for loop in PHP is slower than assigning the
    count to a variable and using that variable in the for loop instead.

```php
// correct
$cnt = count($array);
for ($i = 0; $i < $cnt; $i++) {
    // some logic here
}

// wrong
for ($i = 0; $i < count($array); $i++) {
    // some logic here
}
```

#### foreach

-   Key variable in foreach loop MUST NOT be defined if not used.

Example:

```php
$items = [0 => 'a', 1 => 'b', 2 => 'c'];
foreach ($items as $key => $item) {
    // some logic here
}

$items = [10001 => 'a', 10002 => 'b', 10003 => 'c'];
foreach ($items as $itemid => $item) {
    // some logic here
}
```

-   If array elements are modified within the loop, precede the value
    with `&` instead of the array index. In the end of the loop, the
    variable SHOULD be unset. Avoid using assignment by reference when
    working with large arrays.

Example:

```php
$arr = [1, 2, 3, 4, 'b' => 5, 'a' => 6];
// correct
foreach ($arr as &$value) {
    $value = (int) $value * 2;
}
unset($value);

// wrong
foreach ($arr as $i => $value) {
    $arr[$i] = (int) $value * 2;
}
```

- Array keys MUST NOT be modified while iterating arrays in `foreach` cycles.
PHP does not guarantee the same result in such scenarios.

Example:

```php
foreach ($eventids as $i => $eventid) {
    if ($eventid == 10150) {
        unset($eventids[$i]);
    }
}

foreach ($eventids as $i => $eventid) {
    $eventids = array_flip($eventids);
}
```

#### while, do while

Example:

```php
while ($item = DBfetch($db_items)) {
    // some logic here
}
```

Example:

```php
do {
    echo $i--;
}
while ($i > 0);
```

### Formatting

#### Strings

-   Single quotes SHOULD be used to define strings.
-   Variable substitution is not permitted in double-quoted strings.

Example:

```php
// correct
$a = 'Example String';

// wrong
$a = "Example $string";
```

-   If a concatenation with `.` (a dot) spans multiple lines, the dot is
    at the end of the previous line (not in the beginning of the next
    one).
-   Space (if required) is added at the beginning of the next rows.

Example:

```php
// correct
$sql = 'SELECT i.itemid'.
    ' FROM items i';

// wrong
$sql = 'SELECT i.itemid '
    .'FROM items i';
```

-   Translatable strings are not split into multiple lines.

Example:

```php
// correct
$error = _s('Graph "%1$s" already exists on "%2$s" (inherited from another template).');

// wrong
$error = _s('Graph "%1$s" already exists on "%2$s"'.
    ' (inherited from another template).'
);
```

-   `%s` MUST NOT be used even if there is one parameter.

Example:

```php
// correct
$error = _s('Invalid key "%1$s".', $item['_key']);

// wrong
$error = _s('Invalid key "%s".', $item['_key']);
```

#### Translatable strings

In order to make a string translatable in Zabbix you have to just wrap
the original string in a function call:

```php
$hello = _('Hello, dear user!');
```

New translatable strings are automatically parsed behind the scene and stored in `/ui/locale` directory.

To use string translations in preprocessed JavaScript files (.js.php files) PHP short tags MUST be used, and the `json_encode` will take care of correctly escaping the potential quotes in the actual translation.

Example:

```js
const label = <?= json_encode(_('Trigger')); ?>;
```

To use string translations in global JavaScript files (.js files), the translations MUST be added to the `$translate_strings` array in `/ui/jsLoader.php`.

*Placeholders*

To put variables inside the string, you SHOULD use the Zabbix
frontend `_s()` function:

```php
_s('Hosts deleted: %1$s.', $hosts_deleted);
```

If more than one variable is inserted, variable placeholders MUST have
order number.

Example:

```php
_s('Item [%1$s] deleted from template [%2$s].', $item, $template);
```

*Plurals*

The output from the previous example would be: "Hosts deleted: 8.". To
make this string more human-readable, you can use the Zabbix frontend
`_n()` function:

```php
_n('Deleted %1$s host.', 'Deleted %1$s hosts.', $hosts_deleted);
```

```php
"Deleted 1 host."
"Deleted 8 hosts."
```

Even if the original text might not require any count for singular form,
the number placeholder still MUST be used. For example, "Last %1$s
issue" instead of just "Last issue". Omitting the number from the
English version requires the translators to know that it MUST be added,
and thus is error-prone.

Make sure both Singular and Plural strings have the same parameters used in them.
Otherwise, translation file sync will be broken. <https://support.zabbix.com/browse/ZBX-23554>

For information on plural strings in the po file, consult
<http://www.gnu.org/software/hello/manual/gettext/Plural-forms.html> and
<http://translate.sourceforge.net/wiki/l10n/pluralforms>.

*Disambiguation by context*

Sometimes one term is used in several contexts and although it is one
and the same word in English it has to be translated differently in
other languages. For example, the word Post can be used both as a verb
(Click here to post your comment) and as a noun (Edit this post). In
such cases the `_x()` function SHOULD be used. It is similar to `_s()`,
but it has an additional second argument - the context:

```php
$column = _x('Change', 'noun in latest data');
...
// some other place in the code
$button = _x('Change', 'action button');
```

By using this method in both cases we will get the "Change" string for
the original version, but the translators will see two "Change" strings
for translation, each in the different contexts.

`_xn()` function is similar to `_n()` function except that it also
supports context as the fourth parameter.

Both functions support the unlimited number of placeholders.

Example:

```php
_x('Message for arg1 "%1$s" and arg2 "%2$s"', 'context', 'arg1Value', 'arg2Value');
//returns: 'Message for arg1 "arg1Value" and arg2 "arg2Value"'

_xn('%1$s message for arg1 "%2$s"', '%1$s messages for arg1 "%2$s"', 3, 'context', 'arg1Value');
//returns: '3 messagges for arg1 "arg1Value"'
```

*Recommendations*

It's recommended to avoid using the context and gettext comments
together for a particular string. But if the short context is not
sufficiently descriptive, then the gettext comment is allowed. The
reason is that Pootle, Virtaal tools have a minor disadvantage in using
gettext comments (// GETTEXT:) together with the context. The gettext
comment will replace information about source code lines where this
string is used.

A very short context (in one word) is NOT RECOMMENDED, it's less clear
and less noticeable in the translation tools. The recommended length is
2-3 words. It is NOT RECOMMENDED to use any punctuation for context
string.

For example the code could be (a real approved usage):

```php
$pagespan = new CSpan('< '._x('Previous', 'page navigation'), 'darklink');
DOBJECT_STATUS_UP => _x('Up', 'discovery status'),
new CCol(_x('Up', 'discovery results in dashboard')),
$maintenance_status = new CSpan(_x('Active', 'maintenance status'), 'green');
['pow' => 3, 'short' => _x('G', 'Giga short'), 'long' => _('Giga')],
```

*Date and time*

Rather than using the built-in PHP locale switching features, which are
not configured for very many languages on most hosts, Zabbix uses its
internal translation module and gettext functions to accomplish date and
time translations and formatting.

These are PHP `date()` formatting strings, and they allow you to change
the formatting of the date and time for your locale.

Zabbix uses the translations elsewhere in the localization file for full
and short textual representations of month names and weekday names.
Format characters that will give translated representations are:
`D l F M`. Description of returned values are the same as for PHP
[date()](http://php.net/manual/en/function.date.php) function.

This special string is to select which elements to include in the date &
time, as well as the order in which they're presented.

*Comments for translators*

If a translatable string might benefit from clarification, a comment for
translators SHOULD be added. Such comments SHOULD be prefixed with
`GETTEXT:`, for example:

```php
// GETTEXT: r is date format string as described in http://php.net/date.
```

This comment will be applied to the **first** found string in the source
code after this comment.

#### Arrays

- There MUST be no trailing comma after the last element, even if it's defined on a separate line.
- The values of non-associative arrays SHOULD be listed in-line.
- If an array is defined on several lines, the closing parenthesis MUST be on a separate line.

Example:

```php
// correct
$data = [
    'username' => $username,
    'password' => $password,
    'email' => $email
];

// wrong
$data = [
    'username' => $username,
    'password' => $password,
    'email' => $email,
];

// correct
$data = [$username, $password, $email];

// wrong
$data = [
    $username,
    $password,
    $email
];

// correct
$trigger_options = [
    'output' => ['triggerid', 'expression', 'description', 'status',
        'value', 'priority'
    ],
    'monitored' => true,
    'preservekeys' => true
];

// wrong
$trigger_options = [
    'output' => ['triggerid', 'expression', 'description', 'status',
        'value', 'priority'],
    'monitored' => true,
    'preservekeys' => true];
```

*Array merging*

- Merging of associative arrays SHOULD be done using the `+` operator due to better performance.

Example:

```php
// correct
$options += $default_options;

// wrong
$options = array_merge($default_options, $options);
```

*Built-in array functions*

-   It is NOT RECOMMENDED to use `array_push()`.

Example:

```php
// correct
foreach ($hosts as $host) {
     $hostids[] = $host['hostid'];
}

// wrong
foreach ($hosts as $host) {
     array_push($hostids, $host['hostid']);
}
```

- For better performance it is RECOMMENDED to use `array_keys(array_flip())` instead of `array_unique()`.

Example:

```php
// correct
$hostids = array_keys(array_flip($hostids));

// wrong
$hostids = array_unique($hostids);
```

- For better performance a unique data (like IDs) SHOULD be stored as array keys instead of values.

Example:

```php
// correct
$hostids = [];

foreach ($hosts as $host) {
    $hostids[$host['hostid']] = true;
}

if (array_key_exists($hostid, $hostids)) {
    // some logic here
}

// wrong
$hostids = [];

foreach ($hosts as $host) {
    $hostids[] = $host['hostid'];
}

if (in_array($hostid, $hostids)) {
    // some logic here
}
```

- For array keys, `array_key_exists()` MUST be used instead of `isset()`.

Example:

```php
// correct
if (array_key_exists('name', $items)) {
    // some logic here
}

// wrong
if (isset($items['name'])) {
    // some logic here
}
```

*list()*

-   The shorthand `[]` MUST be used for `list()`.

Example:

```php
$data = [
    ['id' => 1, 'name' => 'Tom'],
    ['id' => 2, 'name' => 'Fred']
];

// correct (single line)
['id' => $id, 'name' => $name] = $data[0];

// correct (multiple lines)
[
    'id' => $id,
    'name' => $name
] = $data[0];

// wrong
list('id' => $id, 'name' => $name) = $data[0];

// correct
foreach ($data as ['id' => $id, 'name' => $name]) {
    // logic here with $id and $name
}

// wrong
foreach ($data as list('id' => $id, 'name' => $name)) {
    // logic here with $id and $name
}
```

*Three dot operator*

-   Arrays and Traversable objects MUST NOT be unpacked into argument
    lists when calling functions by using the `...` operator.

Example:

```php
// wrong
function add($a, $b, $c) {
    return ($a + $b + $c);
}

$operators = [2, 3];
$result = add(1, ...$operators);
```

#### Functions

*Function declaration*

-   For function parameter definitions there is no trailing comma after
    the last element both for definitions on single and multiple lines.
-   If a function parameter definition spans multiple lines, closing
    parenthesis SHOULD be similar to `if` statement.

Example:

```php
// correct
public function __construct(array $options, CImportReferencer $referencer,
        CImportedObjectContainer $imported_object_container, CTriggerExpression $trigger_expression) {
    // some logic here
}

// wrong
public function __construct(array $options, CImportReferencer $referencer,
        CImportedObjectContainer $imported_object_container, CTriggerExpression $trigger_expression
    ) {
    // some logic here
}
```

- Setting defaults for function parameters is discouraged, except when semantically justified.
- Using named arguments is allowed, but it's recommended to evaluate whether function refactoring can eliminate their necessity.

Example:

```php
// correct
public function __construct(string $name, string $value, string $action, array $items) {
    // some logic here
}

// wrong
public function __construct(string $name = 'combobox', ?string $value, ?string $action, array $items = []) {
    // some logic here
}

// correct
public function setEnabled(bool $enabled = true) {
    // some logic here
}
```

-   Parameters, that do not fit into a single line SHOULD be written on
    a separate line:

Example:

```php
// correct
monitor_stuff($hostid, $itemid,
    'A long informative message that would not fit if written together with the other parameters'
);

// correct
monitor_stuff($hostid, $itemid, [
    'parameter' => 'value',
    'another_parameter' => 'value'
]);

// wrong
monitor_stuff($hostid, $itemid, 'A long informative message that would not fit if written together with the other parameters');
```

-   The closing line containing the closing parenthesis of a function call MUST always be on the
    same indentation level as the opening line.

Example:

```php
// correct
info(_s(
    'A pretty long message that contains the following parameters: "%1$s", "%2$s", "%3$s"',
    'parameter one',
    'parameter two',
    'parameter three'
));

// wrong
info(_s(
    'A pretty long message that contains the following parameters: "%1$s", "%2$s", "%3$s"',
    'parameter one',
    'parameter two',
    'parameter three'));
```

-   Functions should not access superglobals even using `hasRequest()`
    and `getRequest()` functions, but accept them as parameters.

Example:

```php
// correct
function processItems(array $items): void {
    // some logic here
}

// wrong
function processItems(): void {
    $items = getRequest('items');

    // more logic here
}
```

*Return values*

-   If the function receives a parameter and modifies it, it SHOULD be
    returned, not passed by reference. This SHOULD make the code easier
    to understand and prevent situations when a function modifies the
    array unexpectedly.

Example:

```php
// correct
function modifyValues(array $values): array {
    // some logic here

    // return the modified values
    return $values;
}

// wrong
function modifyValues(array &$values): void {
    // some logic here
}
```

-   Functions SHOULD return values early.

Example:

```php
// good
function foo(int $a, int $b): bool {
    if ($a == 0) {
        return false;
    }

    // more logic here

    return true;
}

// bad
function foo(int $a, int $b): bool {
    if ($a == 0) {
        $result = false;
    }

    // more logic here

    return $result;
}
```

#### Classes

-   The term "class" refers to all classes, interfaces, and traits.
-   Only one class is permitted in each PHP file.
-   Variables and methods inside classes MUST always declare their
    visibility by using one of the `private`, `protected`, or `public`
    modifiers. The `var` construct is not permitted.
-   Method chaining MUST be supported and used where applicable.

Example:

```php
// single method
$passwd_field = (new CPassBox('passwd'))->setWidth(ZBX_TEXTAREA_SMALL_WIDTH);

// multiple methods
$mediatype_form = (new CForm())
    ->setId('mediaTypeForm')
    ->addVar('form', 1);

// multiple methods with submethods
$mediatype_formlist
    ->addRow(_('Type'), $row)
    ->addRow(_('SMTP server'),
        (new CTextBox('smtp_server', $data['smtp_server']))->setWidth(ZBX_TEXTAREA_STANDARD_WIDTH)
    )
    ->addRow(_('SMTP email'), (new CTextBox('smtp_email', $data['smtp_email']))->setWidth(ZBX_TEXTAREA_STANDARD_WIDTH))
    ->addRow(_('Connection security'),
        (new CRadioButtonList('smtp_security', (int) $data['smtp_security']))
            ->addValue(_('None'), SMTP_CONNECTION_SECURITY_NONE)
            ->setModern(true)
    )
    ->addRow(_('SSL verify peer'), (new CCheckBox('smtp_verify_peer'))->setChecked($data['smtp_verify_peer']));

// when parameters do not fit into one line, the closing parenthesis for the object is on a new line
$delay_input = (new CNumericBox('delay_flex['.$i.'][delay]', $delay_flex['delay'], 5, $discovered_item, true,
    false
))->setAttribute('placeholder', 50);
```

*Constructor*

- Constructor property promotion is not allowed.

```php
// correct
protected string $name;
protected string $value;

public function __construct(string $name, string $value = '') {
    $this->name = $name;
    $this->value = $value;
}

// wrong
public function __construct(protected string $name, protected string $value = '') {}
```

*Method and function arguments*

- In the argument list, there MUST NOT be a space before each comma,
    and there MUST be one space after each comma.
- When using the reference operator `&` before an argument, there MUST
    NOT be a space after it.
- Since IDs are often stored as array keys, the type of which get automatically converted to `int` or `string`, ID arguments SHOULD NOT have any type specified.

Example:

```php
public function functionName(int $arg1, int &$arg2, array $arg3 = []): void {
    // some logic here
}
```

-   When a return type declaration is present, there MUST be one
    space after the colon followed by the type declaration. The colon
    and declaration MUST be on the same line as the argument list
    closing parenthesis with no spaces between the two characters.

Example:

```php
public function functionName(int $arg1, int $arg2): string {
    return 'foo';
}

public function anotherFunction(string $arg1, string $arg2,
        int $arg3): string {
    return 'foo';
}
```

-   In nullable type declarations, there MUST NOT be a space between the
    question mark and the type.

Example:

```php
public function functionName(?string $arg1, ?int &$arg2, ?array $arg3): ?string {
    return 'foo';
}
```

*abstract, final, and static*

-   When present, the `abstract` and `final` declarations MUST precede
    the visibility declaration.
-   When present, the `static` declaration MUST come after the
    visibility declaration.

Example:

```php
abstract class ClassName {
    protected static $foo;

    abstract protected function methodName();

    final public static function anotherMethod() {
        // some logic here
    }
}
```

#### Blank spaces

-   One blank space MUST be present after commas in argument lists.

Example:

```php
// correct
$a = [1, 2, 3];

// wrong
$a = [1,2,3];

// correct
function updateHostStatus(array $hostids, int $status) {
    // some logic here
}

// wrong
function updateHostStatus(array $hostids,int $status) {
    // some logic here
}
```

-   No blank spaces in a conditional statement after the opening and before
    the closing parenthesis.

Example:

```php
// correct
if ($this->parseConstant()) {
    $constant = end($this->constants);
}

// wrong
if ( $this->parseConstant() ) {
    $constant = end($this->constants);
}
```

-   The increment/decrement operators MUST NOT have any space between
    the operator and operand.

Example:

```php
$i++;
++$j;
```

-   Type casting operators MUST NOT have any space within the
    parentheses.

Example:

```php
$int_value = (int) $input;
```

-   All binary
    [arithmetic](http://php.net/manual/en/language.operators.arithmetic.php)
    except `.` (a dot),
    [comparison](http://php.net/manual/en/language.operators.comparison.php),
    [assignment](http://php.net/manual/en/language.operators.assignment.php),
    [bitwise](http://php.net/manual/en/language.operators.bitwise.php),
    [logical](http://php.net/manual/en/language.operators.logical.php),
    [string](http://php.net/manual/en/language.operators.string.php),
    and [type](http://php.net/manual/en/language.operators.type.php)
    operators MUST be preceded and followed by one space.
-   A keyword followed by a parenthesis MUST be separated by one space.

Examples:

```php
// correct
if (hasRequest('action') && getRequest('action') === 'add') {
    // some logic here
}

// wrong
if (hasRequest('action')&&getRequest('action') === 'add') {
    // some logic here
}

// correct
for ($i = 0; $i < 10; $i++) {
    // some logic here
}

// wrong
for ($i=0; $i<10; $i++) {
    // some logic here
}

// correct
function updateHostStatus(array $hostids, int $status) {
    // some logic here
}

// wrong
function updateHostStatus(array $hostids, int $status){
    // some logic here
}

// correct
function updateHostStatus(array $hostids, int $status) {
    // some logic here
}

// wrong
function updateHostStatus (array $hostids, int $status) {
    // some logic here
}
```

#### Blank lines

-   Blank line SHOULD appear before block comments.
-   One blank line after class declaration.
-   One blank line after method definition in class.
-   Two blank lines after license comment.

#### Comments

- License comments SHOULD NOT be minified (comment with `/*!`).
- Double slashes are only used for simple comments.
- Full sentence comments are preferred over simple comments.
- Readable and self-explaining code is preferred over the comments.

Example:

```php
// simple comment
```

-   Full sentence in a comment starts with a capital letter and ends
    with a dot.

Example:

```php
// This is a full sentence comment.
```

-   If a comment pertains to the whole block between `{` and `}`, it
    SHOULD be written on a separate line at the top of the block
    followed by a blank line.

Example:

```php
if (!$this->error) {
    // Initializing local variables.

    $this->is_valid = true;
    $this->pos = 0;
}
```

-   Block comments can be used with the first letter being capital.

Example:

```php
/*
 * New block comment.
 */
```

-   Full words SHOULD be used in comments instead of shortened
    versions - for example, "parameter" instead of "param".
-   Multiline comments MUST use "block comment" syntax.

Example:

```php
/*
 * After {$ there was something else. This is not a valid macro. Reset and look for macros
 * in the rest of the string.
 */
```

- Standalone term "ID" and its plural form "IDs" MUST be written with capital "ID".

Example:

```php
// Collect IDs.
```

#### PHPDoc

-   All public functions, methods, and properties SHOULD have a
    [PHPDoc](https://docs.phpdoc.org/references/phpdoc/index.html)
    comment with a brief description of its purpose and interface.
-   Private functions, methods, and properties, while exempt from PHPDoc
    comments, MUST be named in a self-explanatory manner, ensuring clear
    understanding of their purpose within the codebase.
-   Tag descriptions MUST be aligned using spaces and tags belonging to
    one group SHOULD be separated by a single line to improve
    readability.
-   If the function doesn't return a value `@return` is not needed.
-   For more than two types it's better to combine types using the pipe
    char instead of `mixed`.
-   It is better to write `@throws` after parameters.
-   Methods and functions marked as `@deprecated` MUST NOT be used for
    new code.

Example :

```php
<?php declare(strict_types = 0);

/**
 * Performs a cool magic trick.
 * 
 * @param FairyDust $fairy_dust    The FairyDust object to use in the trick.
 * @param array     $magic_stones  An array of magic stones.
 * @param int       $stones_limit  Limit of magic stones.
 *
 * @throws Exception if something goes wrong.
 *
 * @return int|null
 */
function performMagic(FairyDust $fairy_dust, array $magic_stones, int $stones_limit): ?int {
    // some logic here
}
```

-   Additional parameter `'@see`' can be used. It SHOULD be written after the description and before the parameters.

Example:

```php
<?php declare(strict_types = 0);

/**
 * Performs a cool magic trick.
 *
 * @see MyClass::__constructor()
 *
 * @param FairyDust $fairy_dust    The FairyDust object to use in the trick.
 * @param array     $magic_stones  An array of magic stones.
 * @param int       $stones_limit  Limit of magic stones.
 *
 * @throws Exception if something goes wrong.
 */
public static function performMagic(FairyDust $fairy_dust, array $magic_stones, int $stones_limit): void {
    // some logic here
}
```

-   Class properties SHOULD have a PHPDoc comment with `@var` parameter
    and property type.

Example:

```php
/**
 * IP address range with maximum amount of IP addresses.
 *
 * @var string
 */
private $max_ip_range;
```

#### File includes

For file include `require_once` is used. `require_once` raises a fatal
error if the file is not found. The path MUST be relative to the directory of the current file.

Example:

```php
// correct
require_once __DIR__.'/include/hosts.inc.php';

// wrong
require_once dirname(__FILE__).'/include/hosts.inc.php';

// wrong
require_once 'include/hosts.inc.php';
```

#### Using PHP in HTML or JavaScript

-   When using PHP in HTML or JavaScript code the alternative control
    structure syntax MUST be used.
-   Do not generate dynamic JavaScript code using PHP. Instead, move the logic directly into the JavaScript code.

Example:

```html
<!-- correct -->
<ul>
    <?php if ($list): ?>
        <?php foreach ($list as $element): ?>
            <li><?= $li ?></li>
        <?php endforeach ?>
    <?php endif ?>
</ul>

<!-- wrong -->
<ul>
    <?php if ($list) { ?>
        <?php foreach ($list as $element) { ?>
            <li><?php echo $li ?></li>
        <?php } ?>
    <?php } ?>
</ul>
```

```javascript
// correct
var is_profile = <?= $this->data['is_profile'] ?>;

if (is_profile) {
    document.addEventListener('load', () => {
        fields_to_trim.push('#alias', '#name', '#surname');
    });
}

// wrong
<?php if ($data['is_profile']): ?>
    document.addEventListener('load', () => {
        fields_to_trim.push('#alias', '#name', '#surname');
    });
<?php endif ?>
```

#### Data escaping

- The unsafe data must be correctly escaped for output in HTML and JavaScript to prevent XSS attacks.
- To output unsafe data directly into an HTML context, usage of `CTag` class or its descendants like 
`CDiv`, `CSpan`, `CLink` and others is RECOMMENDED, as the `CTag` class will take care of correctly escaping the data.

Example:

```php
// correct
(new CDiv($data['unsafe_content']))->show();

// wrong
<div><?= $data['unsafe_content'] ?></div>
```

- To output unsafe data without wrapping it into an HTML tag, `CHtml::encode()` method MUST be used. This approach is
only allowed if there is no possibility to make use of `CTag` class or its descendants like `CDiv`, `CSpan`, `CLink` and others.

Example:

```php
// correct
<?= CHtml::encode($data['unsafe_content']) ?>

// wrong
<?= $data['unsafe_content'] ?>

// wrong
<div><?= CHtml::encode($data['unsafe_content']) ?></div>
```

- To encode the unsafe data into HTML attributes, the `CTag::setAttribute()` method MUST be used for each data string.

Example:

```php
// correct
(new CDiv())
    ->setAttribute('data-unsafe-string', $data['unsafe_string'])
    ->show();

// wrong
<div data-unsafe-string="<?= $data['unsafe_string'] ?>"></div>

// wrong
<div data-unsafe-string="<?= CHtml::encode($data['unsafe_string']) ?>"></div>
```

- To encode array of unsafe data into a single HTML attribute, the data MUST first be JSON encoded and then 
  the `CTag::setAttribute()` method MUST be used for the encoded JSON string.

Example:

```php
// correct
(new CDiv())
    ->setAttribute('data-unsafe-array', json_encode($data['unsafe_array']))
    ->show();
```

- Multiple escaping layers or partial escaping of HTML attributes MUST NOT be ever used for HTML output.

Example:

```php
// correct
(new CDiv())
    ->setAttribute('data-unsafe-string', $data['unsafe_string'])
    ->setAttribute('onclick', 'alert(this.dataset.unsafeString);')
    ->show();

// wrong
(new CDiv())
    ->setAttribute('onclick', 'alert("'.$data['unsafe_string'].'");')
    ->show();

// wrong
(new CDiv())
    ->setAttribute('onclick', 'alert("'.CHtml::encode($data['unsafe_string']).'");')
    ->show();
```

- The PHP data SHOULD NOT be directly accessed by the JavaScript code. Instead, the PHP should initialize the JavaScript
code by JSON-encoding the necessary data as function parameters.

Example:

```php
// correct
(new CScriptTag('
    view.init('.json_encode([
        'unsafe_string' => $data['unsafe_string',
        'unsafe_array' => $data['unsafe_array']
    ]).');
'))
    ->setOnDocumentReady()
    ->show();
```

```javascript
// correct
const view = new class {
    init({unsafe_string, unsafe_array}) {
        console.log(unsafe_string);
        console.log(unsafe_array);
    }
}
```

- Translatable strings MUST also be encoded because they can contain special characters like ampersands or quotes.

```javascript
// correct
console.log(<?= json_encode(_('Triggers')) ?>);
```

### Using the API

-   `API_OUTPUT_EXTEND` MUST never be used when performing get requests
    since it will request unnecessary data and may result in poor
    performance. Pass an array of specific fields instead.
-   API `get()` method options SHOULD be sorted in the following order:
    -   `output` (only the fields that will be used in the following
        code MUST be specified) or `countOutput`
    -   `groupCount` (is only used together with `countOutput`)
    -   additional table fields, for example, `selectItems`
    -   IDs, for example `hostids`
    -   flags (`skipDependent`, `monitored`, `editable` etc.)
    -   `filter`
    -   `search`
    -   `sortfield`
    -   `sortorder`
    -   `limit`
    -   `preservekeys`

Example:

```php
$triggers = API::Trigger()->get([
    'output' => ['triggerid', 'description'],
    'selectItems' => ['itemid', 'name'],
    'selectLastEvent' => ['acknowledged'],
    'hostids' => $hostids,
    'skipDependent' => true,
    'monitored' => true,
    'editable' => true,
    'filter' => ['state' => null],
    'sortfield' => ['priority'],
    'sortorder' => ZBX_SORT_UP,
    'limit' => 1,
    'preservekeys' => true
]);
```

### Input field limits

All input fields in the frontend are limited according to what the
receiving database field length limit is. API does input length
validation the same way.

For example:

-   IP input fields are limited to 39 characters (to accommodate IPv6
    addresses and user macros).
-   DNS input fields are limited to 64 characters.
-   Port input fields are limited to 64 characters (to accommodate user
    macros).

### Handling incorrect user input

If the user input is incorrect (text for a numeric value, too large
number, incorrect symbols used, etc.), it is never trimmed, discarded,
or modified - all user input is preserved as-is.

### API development rules

-   API method chaining should not be used, because it would simply not
    work correctly.

```php
// correct
$groupids = API::HostGroup()->get([]);

API::Host()->get([
    'groupids' => $groupids
]);

// wrong
API::Host()->get([
    'groupids' => API::HostGroup()->get([])
]);
```

-   `$sql_parts['limit']` vs `$options['limit']` : limit should be validated. If API method has API validation and limit is validated as part of it, no additional validation is required and `$options['limit']` SHOULD be used. Otherwise we should use the following code sample.

```php
// limit
if (zbx_ctype_digit($options['limit']) && $options['limit']) {
    $sql_parts['limit'] = $options['limit'];
}
```

-   `API_ALLOW_NULL` flag SHOULD often be used in validation in `api.get` methods (make sure to check it's usage in similar fields in existing APIs). This flag SHOULD NOT be used in `api.create` and `api.update` methods, where validation should be more strict.
-   All `$sql_parts` SHOULD be initialized in beginning of api.get method (don't omit unused ones). `limit` SHOULD be omitted, if `$options['limit']` will be used as in rule above.

```php
$sql_parts = [
    'select'    => ['dashboard' => 'd.dashboardid'],
    'from'      => ['dashboard' => 'dashboard d'],
    'where'     => [],
    'order'     => [],
    'group'     => [],
    'limit'     => null
];
```

-   `api.get` SHOULD NOT return primary key in its objects, if it was not requested in `output`.
-   If possible, API validation rules SHOULD be formatted as a single block without separation into variables or functions.
-   `api.create` and `api.update` methods should return ids in wrapper object.

```php
    return ['dashboardids' => $dashboardids];
```

-   `API_NOT_EMPTY` flag was not implemented for `API_OBJECT` validation on purpose. If an object has no required fields, it MAY be empty.
-   `createRelationMap()` and related methods SHOULDN'T be used. Instead fetch each row from select separately and put the data, where needed.

```php
// correct
$groupPrototypes = DBFetchArrayAssoc(DBselect('...'), 'group_prototypeid');
foreach ($result as $id => $host) {
    $result[$id]['groupPrototypes'] = [];
}
$query = DBselect(
    'SELECT ...'.
    ' WHERE '.dbConditionInt('group_prototypeid', array_keys($groupPrototypes))
);
while ($groupPrototype = DBFetch($query)) {
    $result[$groupPrototype['hostid']]['groupPrototypes'][] = $groupPrototype;
}

// wrong
$groupPrototypes = DBFetchArray(DBselect('...'));
$relationMap = $this->createRelationMap($groupPrototypes, 'hostid', 'group_prototypeid');
$groupPrototypes = API::getApiService()->select('group_prototype', [
    'group_prototypeids' => $relationMap->getRelatedIds(),
    ...
]);
$result = $relationMap->mapMany($result, $groupPrototypes, 'groupPrototypes');
```

-   Functions `DBstart()` and `DBend()` are useful in controllers to revert changes from multiple API requests if later one fails. But there is no need to use these functions for just one API call, as an API call uses them itself.

```php
// correct
DBstart();
$result = API::HostGroup()->update([
    'groupid' => $groupid,
    'name' => $name
  ]);
if ($result) {
  $result = API::HostGroup()->propagate([
    'groups' => ['groupid' => $groupid],
    'permissions' => true
  ]);
}
$result = DBend($result);

//wrong
DBstart();
$result = API::HostGroup()->create(['name' => $name]);
$result = DBend($result);
```
