import io
import logging
import unittest

from app.logging_config import PlainConsoleFormatter, ServerConsoleLogConfig


class LoggingConfigTests(unittest.TestCase):
    def test_plain_console_formatter_strips_ansi_colors(self):
        formatter = PlainConsoleFormatter("%(message)s")
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname=__file__,
            lineno=1,
            msg="\x1b[32mserver started\x1b[0m",
            args=(),
            exc_info=None,
        )

        self.assertEqual(formatter.format(record), "server started")

    def test_configure_sets_plain_formatter_on_existing_handlers(self):
        stream = io.StringIO()
        handler = logging.StreamHandler(stream)
        logger = logging.getLogger("uvicorn.error")
        original_handlers = logger.handlers[:]
        original_level = logger.level
        original_propagate = logger.propagate

        try:
            logger.handlers = [handler]
            logger.propagate = False
            ServerConsoleLogConfig.configure()

            logger.info("\x1b[31mhello\x1b[0m")

            output = stream.getvalue()
            self.assertIn("INFO [uvicorn.error] hello", output)
            self.assertNotIn("\x1b[31m", output)
        finally:
            logger.handlers = original_handlers
            logger.setLevel(original_level)
            logger.propagate = original_propagate


if __name__ == "__main__":
    unittest.main()
