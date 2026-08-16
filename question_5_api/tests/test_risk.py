import pytest

from question_5_api.risk import compute_risk, query_ae, risk_category, severity_points


def test_severity_points_mapping():
    assert severity_points("MILD") == 1
    assert severity_points("MODERATE") == 3
    assert severity_points("SEVERE") == 5
    assert severity_points("mild") == 1  # case-insensitive
    assert severity_points("UNKNOWN") == 0
    assert severity_points(None) == 0


@pytest.mark.parametrize(
    "score,category",
    [(0, "Low"), (4, "Low"), (5, "Medium"), (14, "Medium"), (15, "High"), (40, "High")],
)
def test_risk_category_thresholds(score, category):
    assert risk_category(score) == category


def test_compute_risk_sums_points_and_categorises(adae_small):
    res = compute_risk(adae_small, "01-701-1015")  # 1 + 3 + 5 = 9
    assert res is not None
    assert res.subject_id == "01-701-1015"
    assert res.risk_score == 9
    assert res.risk_category == "Medium"
    low = compute_risk(adae_small, "01-701-1028")  # 1
    assert low.risk_score == 1 and low.risk_category == "Low"


def test_compute_risk_unknown_subject_returns_none(adae_small):
    assert compute_risk(adae_small, "99-999-9999") is None


def test_query_ae_no_filters_returns_everything(adae_small):
    res = query_ae(adae_small, severity=None, treatment_arm=None)
    assert res.count == 6
    assert res.subjects == ["01-701-1015", "01-701-1023", "01-701-1028"]


def test_query_ae_filters_are_anded_and_case_insensitive(adae_small):
    res = query_ae(adae_small, severity=["mild", "MODERATE"], treatment_arm="placebo")
    assert res.count == 2
    assert res.subjects == ["01-701-1015"]


def test_query_ae_empty_severity_list_is_ignored(adae_small):
    res = query_ae(adae_small, severity=[], treatment_arm="Xanomeline High Dose")
    assert res.count == 2 and res.subjects == ["01-701-1023"]


def test_query_ae_unknown_values_match_nothing(adae_small):
    res = query_ae(adae_small, severity=["FATAL"], treatment_arm=None)
    assert res.count == 0 and res.subjects == []
