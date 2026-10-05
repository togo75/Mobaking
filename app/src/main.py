import os

from bambara_normalizer import BambaraNumberNormalizer  # type: ignore
from flask import Flask, jsonify, request

PORT = 55001
app = Flask(__name__) # NOSONAR - API locale stateless, non exposée au réseau
normalizer = BambaraNumberNormalizer() 


def _payload_with(field: str):
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return None, (jsonify(error="Request body must be a JSON object"), 400)
    value = data.get(field)
    is_amount = data.get("is_amount")
    if value is None or not str(value).strip():
        return None, (jsonify(error=f"'{field}' must be non-empty"), 400)
    if not isinstance(is_amount, bool):
        return None, (jsonify(error="'is_amount' must be a boolean"), 400)
    return (str(value).strip(), is_amount), None


def _parse_single_digit(word: str) -> str:
    raw = str(normalizer.denormalize(word, is_money=False)).strip()
    if not raw.isdigit() or len(raw) != 1:
        raise ValueError(f"'{word}' did not normalize to one digit")
    return raw


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/getSpelledNum")
def get_spelled_number():
    payload, error = _payload_with("number")
    if error:
        return error
    assert payload is not None
    number, is_amount = payload
    try:
        spelled = normalizer(number, is_money=is_amount)
        if not isinstance(spelled, str) or not spelled.strip():
            raise ValueError("normalizer returned an empty/non-string value")
        return {"spelled_number": spelled.strip()}
    except (TypeError, ValueError) as exc:
        return jsonify(error=str(exc)), 422
    except Exception as exc:
        app.logger.exception("getSpelledNum failed")
        return jsonify(error=str(exc)), 500


@app.post("/getDigits")
def get_number_in_digits():
    payload, error = _payload_with("phrase")
    if error:
        return error
    assert payload is not None
    phrase, is_amount = payload
    try:
        if is_amount:
            raw = normalizer.denormalize(phrase, is_money=True)
            digits = str(raw).strip()
            if not digits.isdigit() or int(digits) <= 0:
                raise ValueError(f"invalid amount result: {digits}")
        else:
            words = phrase.replace(",", " ").replace("-", " ").split()
            digits = "".join(_parse_single_digit(w) for w in words)
            if not digits:
                raise ValueError("no digits were parsed")
        return {"digits": digits}
    except (TypeError, ValueError) as exc:
        return jsonify(error=str(exc)), 422
    except Exception as exc:
        app.logger.exception("getDigits failed")
        return jsonify(error=str(exc)), 500


if os.environ.get("BAMKING_TESTING") != "1":
    app.run(host="127.0.0.1", port=PORT, threaded=False)