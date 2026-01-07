# PHP Coding Guidelines (Annotated)

**Legend:**
✅ = Implementable via Tree-sitter Query + Thin Lua
🚧 = Implementable via Lua/Vim APIs (Filesystem, Buffer options, Regex)
⛔ = Difficult/Impossible (Requires manual review or dedicated formatter)

## 1. General Guidelines
- ⛔ **Language:** All code and comments MUST be written in English.
- ✅ **Global Scope:** Global variables MUST NOT be used.
- ✅ **Database:** Zabbix API methods MUST be used instead of direct SQL queries (heuristic check).
- 🚧 **.htaccess:** Files only define settings for the current directory.

## 2. File Structure & Organization
- ✅ **Tags:** Files MUST start with `<?php` on the first line. The closing `?>` tag MUST be omitted for pure PHP files.
- 🚧 **Encoding:** UTF-8 without BOM.
- 🚧 **Line Endings:** Unix LF (linefeed) only.
- 🚧 **EOF:** Files MUST end with a single non-blank line terminated by LF.
- ✅ **Header Order:** Opening tag -> Copyright -> Namespace -> Use -> Code.
- 🚧 **Definitions:** Global/Translatable defines location checks.
- 🚧 **Directory Hierarchy:** Classes in `classes/`, MVC in `app/`.

## 3. Naming Conventions
- ✅ **Variables:** Lowercase, underscores, self-describing.
- ✅ **Constants:** All uppercase with underscores.
- ✅ **Functions & Methods:** Lowercase start, `camelCase`.
- ✅ **Abbreviations:** Acronyms SHOULD NOT be uppercase (e.g., `exportHtmlSource`).
- ✅ **Visibility:** No single underscore prefix.
- ✅ **Classes:** Start with "C", `CUpperCamelCase`.
- 🚧 **Filenames:** Lowercase, no spaces, matches Class name.

## 4. Formatting & Layout
- 🚧 **Indentation:** MUST use one **tab**. (Use `vim.bo.expandtab = false`).
- 🚧 **Line Length:** MAX 120 chars. (Use `vim.opt.colorcolumn`).
- 🚧 **Trailing Whitespace:** MUST NOT exist.
- ✅ **Statements:** MAX one statement per line.
- ⛔ **Blank Lines:** Specific rules for comments/classes/methods.
- ⛔ **Spacing:** Binary operators, keywords, parentheses spacing (Best handled by formatter).

## 5. Declarations & Types
- ✅ **Keywords:** Reserved keywords/types MUST be lowercase.
- ✅ **Types:** Short forms used (`int`, `bool`).
- ✅ **Arrays:** `[]` shorthand, no trailing comma on last element.
- ✅ **Variables:** Declared on separate lines.
- ✅ **Variable Variables:** `$$var` PROHIBITED.
- ✅ **Superglobals:** `$_REQUEST` PROHIBITED.
- ✅ **Operators:** `??` and `?->` PROHIBITED.

## 6. Control Structures
- ✅ **Conditionals:** Braces `{}` REQUIRED, even for single lines.
- ⛔ **Brace Placement:** Opening `{` on same line, closing `}` on next.
- ✅ **Elseif:** MUST be one word (`elseif`).
- ✅ **Inline Assignments:** Allowed only if used in body.
- ✅ **Ternary:** Elvis `?:` allowed ONLY for arrays.
- ⛔ **Switch Break:** Omitted only for default, indented once.
- ✅ **Switch Braces:** NO curly braces for case blocks.
- ✅ **Loops:** Do NOT call `count()` in `for` condition.
- ✅ **Foreach:** Key variable unused if not defined.
- ✅ **Comparisons:** Strict `===` for strings, `==/!=` for numeric zero.
- ✅ **Empty:** `empty()` PROHIBITED.
- ✅ **IsNull:** `is_null()` PROHIBITED.
- ✅ **DB IDs:** Use `bclib` functions (`bccomp`).

## 7. Functions & Methods
- ⛔ **Declaration Spacing:** Space after commas, return type spacing.
- ✅ **Nullable Types:** No space between `?` and type (Node adjacency check).
- ✅ **Parameters:** NO trailing comma.
- ✅ **Defaults:** Discouraged.
- ✅ **ID Arguments:** SHOULD NOT have type hints.
- ⛔ **Reference Spacing:** NO space after `&`.
- ✅ **Behavior:** Return early.
- ✅ **Modifying References:** Discouraged.
- ✅ **Superglobals:** SHOULD NOT access superglobals directly.

## 8. Classes & Objects
- ✅ **Structure:** Only one class per file.
- ✅ **Visibility:** REQUIRED (`public`, `protected`, `private`). `var` forbidden.
- ✅ **Modifiers Order:** `abstract/final` -> visibility -> `static`.
- ✅ **Instantiation:** Parentheses REQUIRED (`new Class()`).
- ✅ **Constructors:** Property promotion PROHIBITED.
- ✅ **Method Chaining:** Supported.

## 9. Comments & Documentation
- ✅ **Style:** Start with capital, end with dot.
- ✅ **Block Comments:** `/* */` for blocks.
- ✅ **PHPDoc:** REQUIRED for public methods.
- ✅ **PHPDoc Tags:** `@throws` after params.
- ✅ **Deprecated:** `@deprecated` implies prohibited.
- ✅ **Translation:** Comments prefixed with `GETTEXT:`.

## 10. Data Handling & Database
- ✅ **SQL:** Variables escaped via `zbx_dbstr()`, Constants NOT escaped.
- ✅ **Array Merge:** Use `+` operator.
- ✅ **Array Uniqueness:** Use `array_keys(array_flip())`.
- ✅ **Keys Check:** Use `array_key_exists()`.
- ✅ **Array Push:** `array_push()` PROHIBITED.
- ✅ **Unpacking:** `...` PROHIBITED for arguments.
- ✅ **Translation:** Wrap strings in `_()`, `_s()`, `_n()`.

