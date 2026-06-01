def container_number_prompt() -> str:
    return (
        "Read the ISO 6346 shipping container number from this image. "
        "Return only the 11-character container number, or NOT_FOUND."
    )
