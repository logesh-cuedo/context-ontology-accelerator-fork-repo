"""Unit tests for coa_consistency.serve_hook (fake SSM and S3, no AWS)."""

import asyncio
import io
import json

from coa_consistency.serve_hook import ConsistencyHook, Tier2Consistency, normalize_question, question_parts, same_words


class _NotFound(Exception):
    pass


class FakeSSM:
    class exceptions:  # noqa: N801 - mirrors boto3
        ParameterNotFound = _NotFound

    def __init__(self, params):
        self.params, self.calls = params, 0

    def get_parameter(self, Name):  # noqa: N803 - boto3 signature
        self.calls += 1
        if Name not in self.params:
            raise _NotFound(Name)
        return {"Parameter": {"Value": self.params[Name]}}


class FakeS3:
    class exceptions:  # noqa: N801 - mirrors boto3
        NoSuchKey = _NotFound

    def __init__(self, objects=None):
        self.objects = dict(objects or {})

    def get_object(self, Bucket, Key):  # noqa: N803
        if (Bucket, Key) not in self.objects:
            raise _NotFound(Key)
        return {"Body": io.BytesIO(self.objects[(Bucket, Key)])}

    def put_object(self, Bucket, Key, Body, ContentType):  # noqa: N803
        self.objects[(Bucket, Key)] = Body

    def list_objects_v2(self, Bucket, Prefix, MaxKeys):  # noqa: N803
        keys = sorted(k for b, k in self.objects if b == Bucket and k.startswith(Prefix))
        return {"Contents": [{"Key": k, "LastModified": ""} for k in keys[:MaxKeys]]}


class Trace:
    def __init__(self):
        self.steps = []

    def record(self, step, status, ms, detail=None):
        self.steps.append((step, status, detail))


CONFIG = {"rulesUri": "s3://b/rules.md", "cacheUri": "s3://b/cache/", "topP": 0, "cacheVersion": "1"}


def _hook(config=CONFIG, rules=b"## Rules\n- previous quarter"):
    ssm = FakeSSM({"/cuedo/consistency/ns1": json.dumps(config)})
    s3 = FakeS3({("b", "rules.md"): rules})
    return ConsistencyHook(ssm, s3, "/cuedo"), ssm, s3


def test_normalize_question():
    assert normalize_question("  Hello   World? ") == "hello world"
    assert normalize_question("PAT growth.") == normalize_question("pat  growth")


def test_no_config_means_off():
    hook, _, _ = _hook()
    assert hook.prepare("q", "other-ns", None) is None


def test_bad_json_means_off_and_is_not_cached():
    ssm = FakeSSM({"/cuedo/consistency/ns1": "{not json"})
    hook = ConsistencyHook(ssm, FakeS3(), "/cuedo")
    assert hook.prepare("q", "ns1", None) is None
    assert hook.prepare("q", "ns1", None) is None
    assert ssm.calls == 2  # retried, not cached


def test_rules_topp_and_miss_then_hit():
    hook, _, s3 = _hook()
    ext = hook.prepare("PAT growth Q3FY26?", "ns1", [{"name": "growth"}])
    assert ext.rules.startswith("## Rules") and ext.top_p == 0.0 and ext.cached is None
    ext.save({"sql": "SELECT 1", "confidence": 0.9, "data_source_id": "src", "other": "ignored"})
    stored = json.loads(s3.objects[("b", ext.cache_key)])
    assert stored["sql"] == "SELECT 1" and "other" not in stored and stored["question"] == "pat growth q3fy26"
    again = hook.prepare("pat growth  q3fy26", "ns1", [{"name": "growth"}])
    assert again.cached["sql"] == "SELECT 1"


def test_save_is_skipped_on_a_hit():
    hook, _, s3 = _hook()
    ext = hook.prepare("q", "ns1", None)
    ext.save({"sql": "SELECT 1"})
    hit = hook.prepare("q", "ns1", None)
    hit.save({"sql": "SELECT 2"})
    assert json.loads(s3.objects[("b", hit.cache_key)])["sql"] == "SELECT 1"


def test_changed_metrics_or_cache_version_miss():
    hook, ssm, _ = _hook()
    hook.prepare("q", "ns1", [{"name": "growth"}]).save({"sql": "SELECT 1"})
    assert hook.prepare("q", "ns1", [{"name": "growth", "x": 1}]).cached is None
    ssm.params["/cuedo/consistency/ns1"] = json.dumps({**CONFIG, "cacheVersion": "2"})
    hook._configs.clear()
    assert hook.prepare("q", "ns1", [{"name": "growth"}]).cached is None


def test_no_cache_uri_means_rules_only():
    hook, _, s3 = _hook(config={"rulesUri": "s3://b/rules.md"})
    ext = hook.prepare("q", "ns1", None)
    assert ext.rules and ext.cached is None and ext.cache_key == ""
    ext.save({"sql": "SELECT 1"})
    assert len(s3.objects) == 1  # only the rules file


def test_missing_rules_file_turns_it_off():
    hook, _, _ = _hook(config={**CONFIG, "rulesUri": "s3://b/missing.md"})
    assert hook.prepare("q", "ns1", None) is None


def test_save_never_raises():
    class Broken:
        def put_object(self, **kw):
            raise RuntimeError("s3 down")

    Tier2Consistency(cache_bucket="b", cache_key="k", _s3=Broken()).save({"sql": "SELECT 1"})


def test_before_tier2_records_hit_or_miss():
    hook, _, _ = _hook()
    trace = Trace()
    ext = asyncio.run(hook.before_tier2("q", "ns1", None, trace))
    ext.save({"sql": "SELECT 1"})
    asyncio.run(hook.before_tier2("q", "ns1", None, trace))
    assert [s[1] for s in trace.steps] == ["miss", "hit"]
    assert asyncio.run(hook.before_tier2("q", "other", None, Trace())) is None


def test_strategy_pin():
    from enum import StrEnum

    class Opt(StrEnum):
        A = "nl_to_sql_first"
        B = "nl_to_sql"

    hook, _, _ = _hook(config={**CONFIG, "strategy": "nl_to_sql"})
    assert asyncio.run(hook.strategy_for("ns1", Opt.A)) is Opt.B
    assert asyncio.run(hook.strategy_for("other", Opt.A)) is Opt.A
    bad, _, _ = _hook(config={**CONFIG, "strategy": "nope"})
    assert asyncio.run(bad.strategy_for("ns1", Opt.A)) is Opt.A


S1 = "Please give me the companies which have grown its PAT by 20% during Q3FY26?"


def test_question_parts_protects_numbers_periods_logic_and_terms():
    protected, loose = question_parts(S1, frozenset({"ancillary"}))
    assert protected == ["grown", "pat", "20", "%", "q", "3", "fy", "26"]
    assert loose == ["companies"]
    assert question_parts("market cap of 1,500 crores")[0] == question_parts("market cap of 1500 crores")[0]
    assert question_parts("at least 3 years")[0] == question_parts("atleast 3 years")[0]
    assert question_parts("gve me pat", frozenset({"pat"}))[0] == ["pat"]
    assert "ancillary" in question_parts("Auto ancillary sector", frozenset({"ancillary"}))[0]


def test_same_words_allows_small_typos_only():
    assert same_words(["companies"], ["compnies"])
    assert same_words(["concentration"], ["concentraiton"])
    assert not same_words(["companies"], ["sectors"])
    assert not same_words(["sales"], ["rates"])
    assert not same_words(["companies"], ["companies", "listed"])


def test_typo_hits_cache_but_changed_logic_misses():
    hook, _, _ = _hook()
    hook.prepare(S1, "ns1", None).save({"sql": "SELECT 1"})
    assert hook.prepare(S1, "ns1", None).cached["sql"] == "SELECT 1"
    typo = "Please gve me the compnies which have grown its PAT by 20% during Q3FY26?"
    assert hook.prepare(typo, "ns1", None).cached["sql"] == "SELECT 1"
    for changed in (
        S1.replace("20%", "80%"),
        S1.replace("Q3FY26", "Q2FY26"),
        S1.replace("PAT", "PBT"),
        S1.replace("grown", "declined"),
        S1.replace("companies", "sectors"),
    ):
        assert hook.prepare(changed, "ns1", None).cached is None, changed


def test_protected_terms_file_makes_a_word_exact():
    config = {**CONFIG, "protectedTermsUri": "s3://b/terms.json"}
    hook, _, s3 = _hook(config=config)
    s3.objects[("b", "terms.json")] = json.dumps(["cement", "ancillary"]).encode()
    hook.prepare("EBITDA growth of cement sector in Q1FY26", "ns1", None).save({"sql": "SELECT 1"})
    assert hook.prepare("EBITDA growth of cemnt sector in Q1FY26", "ns1", None).cached is None
    assert hook.prepare("EBITDA growth of cement sectr in Q1FY26", "ns1", None).cached["sql"] == "SELECT 1"


def test_metric_order_does_not_change_the_cache():
    hook, _, _ = _hook()
    a, b = {"name": "a"}, {"name": "b"}
    hook.prepare("q", "ns1", [a, b]).save({"sql": "SELECT 1"})
    assert hook.prepare("q", "ns1", [b, a]).cached["sql"] == "SELECT 1"


def test_verified_answer_wins_and_changed_logic_misses():
    config = {**CONFIG, "answersUri": "s3://b/answers.json"}
    hook, _, s3 = _hook(config=config)
    s3.objects[("b", "answers.json")] = json.dumps([{"question": S1, "sql": "SELECT 482", "confidence": 0.95}]).encode()
    assert hook.prepare(S1, "ns1", [{"name": "x"}]).cached["sql"] == "SELECT 482"
    assert hook.prepare(S1.replace("companies", "compnies"), "ns1", None).cached["sql"] == "SELECT 482"
    assert hook.prepare(S1.replace("20%", "80%"), "ns1", None).cached is None
    ext = hook.prepare(S1, "ns1", None)
    ext.save({"sql": "SELECT 0"})  # a verified hit is never overwritten
    assert hook.prepare(S1, "ns1", None).cached["sql"] == "SELECT 482"
