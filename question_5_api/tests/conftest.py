import pandas as pd
import pytest


@pytest.fixture
def adae_small() -> pd.DataFrame:
    """Six AE records over three subjects, enough to exercise every rule."""
    return pd.DataFrame(
        {
            "USUBJID": [
                "01-701-1015",
                "01-701-1015",
                "01-701-1015",
                "01-701-1023",
                "01-701-1023",
                "01-701-1028",
            ],
            "ACTARM": [
                "Placebo",
                "Placebo",
                "Placebo",
                "Xanomeline High Dose",
                "Xanomeline High Dose",
                "Xanomeline Low Dose",
            ],
            "AESEV": ["MILD", "MODERATE", "SEVERE", "MODERATE", "MODERATE", "MILD"],
            "AETERM": ["HEADACHE", "NAUSEA", "RASH", "PRURITUS", "ERYTHEMA", "DIZZINESS"],
            "AESOC": [
                "NERVOUS SYSTEM DISORDERS",
                "GASTROINTESTINAL DISORDERS",
                "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
                "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
                "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
                "NERVOUS SYSTEM DISORDERS",
            ],
        }
    )
