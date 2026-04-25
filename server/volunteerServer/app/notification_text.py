DEFAULT_NOTIFICATION_SENDER_NAME = "Администрация"
LEGACY_MOJIBAKE_NOTIFICATION_SENDER_NAME = "РђРґРјРёРЅРёСЃС‚СЂР°С†РёСЏ"


def normalize_notification_sender_name(value: str | None) -> str:
    if not value or value == LEGACY_MOJIBAKE_NOTIFICATION_SENDER_NAME:
        return DEFAULT_NOTIFICATION_SENDER_NAME
    return value
