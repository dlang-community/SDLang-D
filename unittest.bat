@echo off

rem At the moment, unit-threaded isn't detecting all all the tests
rem (issue: https://github.com/atilaneves/unit-threaded/issues/43)
rem so when done, run the tests again using built-in test runner.
dub test && dub test --config=unittest-builtin
