"""Test execution service using pytest."""

import asyncio
import logging
import re
import tempfile
from pathlib import Path

from ..models.responses import TestCaseResult

logger = logging.getLogger(__name__)


class TestRunner:
    """Executes pytest tests in isolated environment."""

    async def run_tests(self, function_code: str, test_code: str) -> tuple[list[TestCaseResult], str]:
        """Run pytest tests for generated function.

        Args:
            function_code: The function code to test
            test_code: The pytest test code

        Returns:
            Tuple of (test results list, summary string)
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)

            # Write function code
            function_file = tmpdir_path / "function.py"
            function_file.write_text(function_code)

            # Write test code
            test_file = tmpdir_path / "test_function.py"
            test_file.write_text(test_code)

            # Run pytest
            try:
                process = await asyncio.create_subprocess_exec(
                    "pytest",
                    "-v",
                    "--tb=short",
                    str(test_file),
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    cwd=tmpdir,
                )

                stdout, stderr = await process.communicate()
                output = stdout.decode() + stderr.decode()

                logger.debug(f"Pytest output:\n{output}")

                # Parse pytest output
                results = self._parse_pytest_output(output)
                summary = self._extract_summary(output)

                return results, summary

            except Exception as e:
                logger.error(f"Error running tests: {e}")
                return [
                    TestCaseResult(
                        name="test_execution_error",
                        passed=False,
                        output=f"Failed to execute tests: {e}",
                    )
                ], "0 passed, 1 failed"

    def _parse_pytest_output(self, output: str) -> list[TestCaseResult]:
        """Parse pytest output to extract test results.

        Args:
            output: Raw pytest output

        Returns:
            List of test case results
        """
        results = []

        # Match test result lines like: "test_function.py::test_name PASSED"
        pattern = r"test_\w+\.py::(\w+)\s+(PASSED|FAILED)"
        matches = re.findall(pattern, output)

        for test_name, status in matches:
            passed = status == "PASSED"

            # Extract failure output if test failed
            failure_output = ""
            if not passed:
                failure_pattern = rf"{test_name}.*?(?=test_\w+\.py::|\Z)"
                failure_match = re.search(failure_pattern, output, re.DOTALL)
                if failure_match:
                    failure_output = failure_match.group(0).strip()

            results.append(
                TestCaseResult(
                    name=test_name,
                    passed=passed,
                    output=failure_output,
                )
            )

        # If no tests found, return a placeholder
        if not results:
            results.append(
                TestCaseResult(
                    name="unknown",
                    passed=False,
                    output="No tests found in output",
                )
            )

        return results

    def _extract_summary(self, output: str) -> str:
        """Extract summary line from pytest output.

        Args:
            output: Raw pytest output

        Returns:
            Summary string (e.g., "3 passed, 0 failed")
        """
        # Match summary like: "3 passed in 0.05s" or "1 failed, 2 passed in 0.05s"
        summary_pattern = r"([\d\s\w,]+)\s+in\s+[\d\.]+s"
        match = re.search(summary_pattern, output)

        if match:
            summary = match.group(1).strip()
            return summary

        return "Unknown test results"
