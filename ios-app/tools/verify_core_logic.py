#!/usr/bin/env python3
"""Riesegue in Python gli stessi vettori della suite XCTest.

## Perché esiste

Il progetto è Swift e iOS, ma la macchina su cui viene sviluppato non ha una
toolchain Swift: `swift` e `xcodebuild` non ci sono e il repository dei
toolchain non è raggiungibile. `xcodebuild test` va quindi eseguito su un Mac.

Nel frattempo questo script porta gli **algoritmi puri** — quelli dove i bug
si annidano davvero — e li esercita con gli identici casi limite dei test
Swift. Non verifica la sintassi Swift né il comportamento di SwiftUI: verifica
che il modulo 97, l'aritmetica in centesimi, l'accelerazione, il saldo
derivato e la normalizzazione della firma diano i risultati attesi.

    python3 tools/verify_core_logic.py
"""

import sys

failures = []
checks = 0


def check(label, actual, expected):
    global checks
    checks += 1
    if actual != expected:
        failures.append(f"{label}\n     atteso: {expected!r}\n     ottenuto: {actual!r}")


def section(name):
    print(f"\n  {name}")


# ─────────────────────────────────────────────────────────────────────
# IBANValidator
# ─────────────────────────────────────────────────────────────────────

EXPECTED_LENGTHS = {
    "AD": 24, "AT": 20, "BE": 16, "BG": 22, "CH": 21, "CY": 28, "CZ": 24,
    "DE": 22, "DK": 18, "EE": 20, "ES": 24, "FI": 18, "FR": 27, "GB": 22,
    "GR": 27, "HR": 21, "HU": 28, "IE": 22, "IS": 26, "IT": 27, "LI": 21,
    "LT": 20, "LU": 20, "LV": 21, "MC": 27, "MT": 31, "NL": 18, "NO": 15,
    "PL": 28, "PT": 25, "RO": 24, "SE": 24, "SI": 19, "SK": 24, "SM": 27,
}


def iban_compact(raw):
    return "".join(c for c in raw.upper() if c.isascii() and c.isalnum())


def iban_modulo97(compacted):
    rearranged = compacted[4:] + compacted[:4]
    remainder = 0
    for ch in rearranged:
        if ch.isdigit():
            remainder = (remainder * 10 + int(ch)) % 97
        elif ch.isascii() and ch.isalpha():
            mapped = ord(ch) - 65 + 10
            if not 10 <= mapped <= 35:
                return ("invalidCharacter", ch)
            remainder = (remainder * 100 + mapped) % 97
        else:
            return ("invalidCharacter", ch)
    return ("ok", remainder)


def iban_validate(raw):
    value = iban_compact(raw)
    if not value:
        return ("empty",)
    if len(value) < 15:
        return ("tooShort", 15)
    if len(value) > 34:
        return ("tooLong", 34)

    country = value[:2]
    if not country.isalpha():
        return ("invalidCountryCode",)
    if not value[2:4].isdigit():
        return ("nonNumericCheckDigits",)

    expected = EXPECTED_LENGTHS.get(country)
    if expected is not None and expected != len(value):
        return ("wrongLength", country, expected, len(value))

    kind, payload = iban_modulo97(value)
    if kind != "ok":
        return ("invalidCharacter", payload)
    return ("valid", value) if payload == 1 else ("checksumMismatch",)


def iban_formatted(raw):
    value = iban_compact(raw)
    return " ".join(value[i:i + 4] for i in range(0, len(value), 4))


section("IBANValidator")

check("compact toglie spazi e punteggiatura",
      iban_compact("it60 x054-2811.1010 0000 0123 456"),
      "IT60X0542811101000000123456")

check("formatted raggruppa a quattro",
      iban_formatted("IT60X0542811101000000123456"),
      "IT60 X054 2811 1010 0000 0123 456")

check("formatted è idempotente",
      iban_formatted(iban_formatted("IT60X0542811101000000123456")),
      iban_formatted("IT60X0542811101000000123456"))

for iban in ["IT60X0542811101000000123456", "IT40S0542811101000000123456",
             "NO9386011117947", "NL91ABNA0417164300", "CH9300762011623852957",
             "DE89370400440532013000", "GB82WEST12345698765432",
             "ES9121000418450200051332", "FR1420041010050500013M02606",
             "MT84MALT011000012345MTLCAST001S"]:
    check(f"IBAN valido {iban}", iban_validate(iban)[0], "valid")

check("IBAN valido con spazi utente",
      iban_validate("IT60 X054 2811 1010 0000 0123 456")[0], "valid")
check("validazione restituisce la forma compatta",
      iban_validate("it60 x054 2811 1010 0000 0123 456")[1],
      "IT60X0542811101000000123456")

check("vuoto", iban_validate("")[0], "empty")
check("solo spazi", iban_validate("   ")[0], "empty")
check("troppo corto", iban_validate("IT60X054"), ("tooShort", 15))
check("troppo lungo", iban_validate("IT" + "0" * 40), ("tooLong", 34))
check("paese non alfabetico", iban_validate("1T60X0542811101000000123456")[0], "invalidCountryCode")
check("cifre di controllo non numeriche",
      iban_validate("ITX0X0542811101000000123456")[0], "nonNumericCheckDigits")
check("lunghezza sbagliata per l'Italia",
      iban_validate("IT60X05428111010000001234"), ("wrongLength", "IT", 27, 25))
check("checksum rotto", iban_validate("IT99X0542811101000000123456")[0], "checksumMismatch")
check("una cifra alterata viene intercettata",
      iban_validate("IT60X0542811101000000123457")[0], "checksumMismatch")
check("modulo 97 di un IBAN valido",
      iban_modulo97("IT60X0542811101000000123456"), ("ok", 1))
check("carattere illegale nel modulo 97",
      iban_modulo97("IT60X05428111010000001234!6"), ("invalidCharacter", "!"))


# ─────────────────────────────────────────────────────────────────────
# Money
# ─────────────────────────────────────────────────────────────────────

INT64_MAX = 2**63 - 1
INT64_MIN = -2**63

MAXIMUM_PAYMENT = 5_000 * 100
INITIAL_BALANCE = 250 * 100

CURRENCIES = {
    "eur": ("€", ",", "."),
    "usd": ("$", ".", ","),
    "cad": ("$", ".", ","),
}


def money_group(value, separator):
    digits = str(value)
    if len(digits) <= 3:
        return digits
    out = []
    for index, digit in enumerate(digits):
        if index > 0 and (len(digits) - index) % 3 == 0:
            out.append(separator)
        out.append(digit)
    return "".join(out)


def money_formatted(cents, currency="eur", exact=False):
    symbol, decimal_sep, group_sep = CURRENCIES[currency]
    sign = "-" if cents < 0 else ""
    units = abs(cents // 100) if cents >= 0 else abs(int(cents / 100))
    # In Swift la divisione fra interi tronca verso lo zero.
    units = abs(int(cents / 100))
    fraction = abs(int(cents % 100)) if cents >= 0 else abs(int(-(-cents % 100)))
    fraction = abs(cents) % 100
    whole = money_group(units, group_sep)
    if fraction == 0 and not exact:
        return f"{sign}{symbol}{whole}"
    return f"{sign}{symbol}{whole}{decimal_sep}{fraction:02d}"


def money_stepped(cents, delta, low=0, high=MAXIMUM_PAYMENT):
    raw = cents + delta
    if raw > INT64_MAX:
        raw = INT64_MAX
    elif raw < INT64_MIN:
        raw = INT64_MIN
    return min(max(raw, low), high)


section("Money")

check("250 € in centesimi", 250 * 100, 25_000)
check("5000 € in centesimi", 5_000 * 100, 500_000)
check("importo tondo senza decimali", money_formatted(2_000), "€20")
check("importo con decimali", money_formatted(2_050), "€20,50")
check("forma esatta con decimali sempre", money_formatted(2_000, exact=True), "€20,00")
check("separatore migliaia euro", money_formatted(120_000), "€1.200")
check("separatore migliaia dollaro", money_formatted(120_000, "usd"), "$1,200")
check("negativo con segno davanti al simbolo", money_formatted(-500), "-€5")
check("decimale a una cifra viene riempito", money_formatted(1_205, exact=True), "€12,05")

check("passo +1 €", money_stepped(2_000, 100), 2_100)
check("passo -1 centesimo", money_stepped(2_000, -1), 1_999)
check("non scende sotto zero", money_stepped(0, -100), 0)
check("non scende sotto zero da 50 cent", money_stepped(50, -100), 0)
check("non supera il tetto", money_stepped(MAXIMUM_PAYMENT, 100), MAXIMUM_PAYMENT)
check("non supera il tetto di 1 centesimo", money_stepped(MAXIMUM_PAYMENT, 1), MAXIMUM_PAYMENT)
check("satura invece di traboccare", money_stepped(INT64_MAX, INT64_MAX), MAXIMUM_PAYMENT)


# ─────────────────────────────────────────────────────────────────────
# SerialGenerator
# ─────────────────────────────────────────────────────────────────────

ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

section("SerialGenerator")

check("lunghezza alfabeto", len(ALPHABET), 32)
for excluded in "IO01":
    check(f"alfabeto esclude «{excluded}»", excluded in ALPHABET, False)
check("alfabeto tutto maiuscolo o cifre",
      all(c.isupper() or c.isdigit() for c in ALPHABET), True)
check("nessun duplicato nell'alfabeto", len(set(ALPHABET)), len(ALPHABET))
check("seriale deterministico con generatore a indice crescente",
      "".join(ALPHABET[i] for i in range(8)), "ABCDEFGH")


# ─────────────────────────────────────────────────────────────────────
# DeterministicColor
# ─────────────────────────────────────────────────────────────────────

def hue(name):
    return (sum(ord(c) for c in name) % 360) / 360.0


section("DeterministicColor")

check("stesso nome, stesso colore", hue("Natalie Rossi"), hue("Natalie Rossi"))
check("nome vuoto stabile a zero", hue(""), 0.0)
check("tonalità dentro 0…1", 0 <= hue("Ludovico Einaudi") < 1, True)
check("maiuscole cambiano il colore", hue("natalie") == hue("Natalie"), False)
check("nomi diversi, colori diversi",
      len({hue(n) for n in ["Natalie Rossi", "Marco Bianchi", "Giulia Verdi"]}) > 1, True)


# ─────────────────────────────────────────────────────────────────────
# StepAccelerator
# ─────────────────────────────────────────────────────────────────────

BURST_WINDOW = 0.45


def multiplier_for_streak(streak):
    if streak <= 2:
        return 1
    if streak <= 6:
        return 2
    if streak <= 12:
        return 5
    return 10


class Accelerator:
    def __init__(self, window=BURST_WINDOW):
        self.streak = 0
        self.last_at = None
        self.last_direction = 0
        self.window = window

    def multiplier(self, direction, now):
        within = self.last_at is not None and (now - self.last_at) < self.window
        self.streak = self.streak + 1 if (within and direction == self.last_direction) else 0
        self.last_at = now
        self.last_direction = direction
        return multiplier_for_streak(self.streak)

    def reset(self):
        self.streak = 0
        self.last_at = None
        self.last_direction = 0


section("StepAccelerator")

check("tabella streak 0", multiplier_for_streak(0), 1)
check("tabella streak 2", multiplier_for_streak(2), 1)
check("tabella streak 3", multiplier_for_streak(3), 2)
check("tabella streak 6", multiplier_for_streak(6), 2)
check("tabella streak 7", multiplier_for_streak(7), 5)
check("tabella streak 12", multiplier_for_streak(12), 5)
check("tabella streak 13", multiplier_for_streak(13), 10)
check("tabella streak 500", multiplier_for_streak(500), 10)

acc = Accelerator()
ramp = [acc.multiplier(1, index * 0.1) for index in range(14)]
check("raffica: prime tre a ×1", ramp[:3], [1, 1, 1])
check("raffica: da 4 a 7 a ×2", ramp[3:7], [2, 2, 2, 2])
check("raffica: da 8 a 13 a ×5", ramp[7:13], [5, 5, 5, 5, 5, 5])
check("raffica: oltre a ×10", ramp[13], 10)

acc = Accelerator()
for index in range(10):
    acc.multiplier(1, index * 0.1)
check("pausa azzera la raffica", acc.multiplier(1, 5.0), 1)

acc = Accelerator()
for index in range(10):
    acc.multiplier(1, index * 0.1)
check("cambio di verso azzera la raffica", acc.multiplier(-1, 1.0), 1)

acc = Accelerator()
acc.multiplier(1, 0.0)
acc.multiplier(1, 0.44)
check("dentro la finestra lo streak sale", acc.streak, 1)
acc.multiplier(1, 0.44 + 0.45)
check("sul confine la finestra si chiude", acc.streak, 0)

acc = Accelerator()
acc.multiplier(1, 0.0)
acc.multiplier(1, 0.1)
check("importo dopo due colpi da 1 €", money_stepped(0, 100) + 100, 200)


# ─────────────────────────────────────────────────────────────────────
# TransactionStore — saldo derivato
# ─────────────────────────────────────────────────────────────────────

def effect(direction, cents):
    return -cents if direction == "sent" else cents


def compute_balance(opening, movements):
    return opening + sum(effect(d, c) for d, c in movements)


def validate_payment(balance, cents):
    if cents <= 0:
        return "amountNotPositive"
    if cents > MAXIMUM_PAYMENT:
        return "aboveLimit"
    if cents > balance:
        return "insufficientFunds"
    return None


section("TransactionStore")

check("saldo iniziale", compute_balance(INITIAL_BALANCE, []), 25_000)
check("un invio riduce il saldo",
      compute_balance(INITIAL_BALANCE, [("sent", 2_000)]), 23_000)
check("un incasso aumenta il saldo",
      compute_balance(INITIAL_BALANCE, [("received", 3_000)]), 28_000)
check("somma di tre movimenti",
      compute_balance(INITIAL_BALANCE,
                      [("sent", 2_000), ("sent", 1_050), ("received", 500)]), 22_450)
check("eliminare un movimento riporta il saldo esatto",
      compute_balance(INITIAL_BALANCE, []),
      compute_balance(INITIAL_BALANCE, [("sent", 2_000)]) + 2_000)

check("importo zero rifiutato", validate_payment(25_000, 0), "amountNotPositive")
check("importo negativo rifiutato", validate_payment(25_000, -1), "amountNotPositive")
check("il tetto esatto è ammesso", validate_payment(1_000_000, 500_000), None)
check("un centesimo oltre il tetto è rifiutato",
      validate_payment(1_000_000, 500_001), "aboveLimit")
check("saldo insufficiente", validate_payment(25_000, 30_000), "insufficientFunds")
check("pagare tutto il saldo è ammesso", validate_payment(25_000, 25_000), None)
check("a saldo zero nessun pagamento", validate_payment(0, 1), "insufficientFunds")


# ─────────────────────────────────────────────────────────────────────
# UserSignature
# ─────────────────────────────────────────────────────────────────────

MAX_SIGNATURE = 16


def normalize_signature(raw):
    kept = "".join(c for c in raw.upper()
                   if c.isascii() and (c.isalpha() or c.isdigit() or c == "_"))
    text = kept[:MAX_SIGNATURE]
    return "@" + text if text else "@ME"


section("UserSignature")

check("nome semplice", normalize_signature("Giovanni"), "@GIOVANNI")
check("chiocciola già presente", normalize_signature("@giovanni"), "@GIOVANNI")
check("rumore rimosso", normalize_signature("@@gio vanni!"), "@GIOVANNI")
check("trattino basso conservato", normalize_signature("ben_giannis"), "@BEN_GIANNIS")
check("vuoto", normalize_signature(""), "@ME")
check("solo spazi", normalize_signature("   "), "@ME")
check("solo punteggiatura", normalize_signature("!!!"), "@ME")
check("troncamento", len(normalize_signature("A" * 40)), MAX_SIGNATURE + 1)


# ─────────────────────────────────────────────────────────────────────

print()
if failures:
    print(f"  {len(failures)} CONTROLLI FALLITI su {checks}\n")
    for failure in failures:
        print(f"   ✗ {failure}")
    sys.exit(1)

print(f"  {checks} controlli superati.\n")
print("  Nota: questa è una verifica degli algoritmi, non una build Swift.")
print("  La suite XCTest va eseguita su un Mac con ⌘U o `xcodebuild test`.")
