from __future__ import annotations

import logging
import re
import sys


ANSI_ESCAPE_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


class PlainConsoleFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        return ANSI_ESCAPE_RE.sub("", super().format(record))


class ServerConsoleLogConfig:
    FORMAT = "%(asctime)s %(levelname)s [%(name)s] %(message)s"
    DATE_FORMAT = "%Y-%m-%d %H:%M:%S"
    LOGGER_NAMES = (
        "",
        "app",
        "app.geocode",
        "uvicorn",
        "uvicorn.error",
        "uvicorn.access",
    )

    @classmethod
    def configure(cls, level: int = logging.INFO) -> None:
        formatter = PlainConsoleFormatter(cls.FORMAT, cls.DATE_FORMAT)
        root_logger = logging.getLogger()

        if not root_logger.handlers:
            root_logger.addHandler(logging.StreamHandler(sys.stdout))

        for logger_name in cls.LOGGER_NAMES:
            logger = logging.getLogger(logger_name)
            logger.setLevel(level)

            if not logger.handlers:
                continue

            for handler in logger.handlers:
                handler.setFormatter(formatter)
                handler.setLevel(level)

        root_logger.setLevel(level)
