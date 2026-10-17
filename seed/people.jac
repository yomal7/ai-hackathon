# Seed: places, the story elders, guardians, analyst and 20 normal citizens - all fictional (A)
import from graph.nodes { Bank, Citizen, Device, Place, Habit, Account, Guardian, Analyst, Lang, AccountKind }
import from graph.edges { Uses, Usually, Has, ProtectedBy }
import from seed.banks { open_account }

# Towns. x / y = rough km from Colombo (east, north) - enough for impossible-travel checks.
glob PLACES: dict[str, list[int]] = {
    "Colombo": [0, 0], "Kandy": [85, 35], "Galle": [20, -100], "Kurunegala": [55, 75],
    "Trincomalee": [165, 195], "Negombo": [5, 32], "Matara": [55, -130], "Anuradhapura": [75, 170],
    "Jaffna": [55, 340], "Batticaloa": [200, 90], "Kalmunai": [205, 60], "Vavuniya": [75, 230]
};

# 20 normal citizens (mix of si / ta / en, ages 25-80). bill = usual electricity bill.
glob NORMAL_CITIZENS: list[dict[str, any]] = [
    {"id": "c_nimal", "name": "Nimal Perera", "age": 45, "city": "Colombo", "lang": "si", "bank": "LDB", "bill": 7500},
    {"id": "c_kumari", "name": "Kumari Silva", "age": 38, "city": "Kandy", "lang": "si", "bank": "CDB", "bill": 5200},
    {"id": "c_sunil", "name": "Sunil Bandara", "age": 62, "city": "Kurunegala", "lang": "si", "bank": "IDB", "bill": 4800},
    {"id": "c_chamari", "name": "Chamari Gunasekara", "age": 29, "city": "Negombo", "lang": "si", "bank": "LDB", "bill": 3900},
    {"id": "c_ruwan", "name": "Ruwan Dissanayake", "age": 51, "city": "Matara", "lang": "si", "bank": "CDB", "bill": 6100},
    {"id": "c_sandya", "name": "Sandya Wickrama", "age": 77, "city": "Galle", "lang": "si", "bank": "IDB", "bill": 3500},
    {"id": "c_pradeep", "name": "Pradeep Ranasinghe", "age": 33, "city": "Kandy", "lang": "si", "bank": "LDB", "bill": 4400},
    {"id": "c_anula", "name": "Anula Herath", "age": 80, "city": "Anuradhapura", "lang": "si", "bank": "CDB", "bill": 2900},
    {"id": "c_murugan", "name": "Murugan Selvaraj", "age": 48, "city": "Jaffna", "lang": "ta", "bank": "IDB", "bill": 5600},
    {"id": "c_lakshmi", "name": "Lakshmi Kandiah", "age": 66, "city": "Batticaloa", "lang": "ta", "bank": "LDB", "bill": 3300},
    {"id": "c_arjun", "name": "Arjun Sivakumar", "age": 27, "city": "Colombo", "lang": "ta", "bank": "CDB", "bill": 4100},
    {"id": "c_meena", "name": "Meena Rajan", "age": 55, "city": "Trincomalee", "lang": "ta", "bank": "IDB", "bill": 4700},
    {"id": "c_fathima", "name": "Fathima Rizwan", "age": 41, "city": "Kalmunai", "lang": "ta", "bank": "LDB", "bill": 5000},
    {"id": "c_ganesh", "name": "Ganesh Thurai", "age": 72, "city": "Vavuniya", "lang": "ta", "bank": "CDB", "bill": 3100},
    {"id": "c_kavitha", "name": "Kavitha Nadarajah", "age": 35, "city": "Jaffna", "lang": "ta", "bank": "IDB", "bill": 4300},
    {"id": "c_david", "name": "David Ondaatje", "age": 58, "city": "Colombo", "lang": "en", "bank": "LDB", "bill": 9800},
    {"id": "c_sarah", "name": "Sarah de Silva", "age": 31, "city": "Colombo", "lang": "en", "bank": "CDB", "bill": 6800},
    {"id": "c_michael", "name": "Michael Van Twest", "age": 69, "city": "Negombo", "lang": "en", "bank": "IDB", "bill": 5900},
    {"id": "c_anne", "name": "Anne Jansz", "age": 44, "city": "Kandy", "lang": "en", "bank": "LDB", "bill": 6300},
    {"id": "c_ravi", "name": "Ravi Mendis", "age": 25, "city": "Galle", "lang": "en", "bank": "CDB", "bill": 3600}
];

glob PHONES: list[str] = ["Galaxy A12 (Android)", "Redmi 9 (Android)", "iPhone 11", "Galaxy A32 (Android)", "Nokia G20 (Android)"];

"""Account id of the i-th normal citizen."""
def normal_account_id(i: int) -> str {
    return f"{NORMAL_CITIZENS[i]['bank']}-{50011 + i * 137}";
}

"""Create the town Place nodes on root."""
def seed_places() -> dict[str, Place] {
    places: dict[str, Place] = {};
    for (name, xy) in PLACES.items() {
        p = Place(name=name, x=xy[0], y=xy[1]);
        root ++> p;
        places[name] = p;
    }
    return places;
}

"""Create a citizen on root with a trusted phone and a usual place."""
def add_citizen(
    cid: str, name: str, age: int, city: str, lang: str,
    phone: str, phone_since: str, places: dict[str, Place]
) -> Citizen {
    c = Citizen(id=cid, name=name, age=age, city=city, language=Lang(lang), is_elder=age >= 65);
    root ++> c;
    c +>:Uses:+> Device(id=f"d_{cid[2:]}", kind=phone, first_seen=phone_since, trusted=True);
    c +>:Usually:+> places[city];
    return c;
}

def add_habit(c: Citizen, action: str, label: str, amount: int, hour_from: int, hour_to: int, count: int) {
    c +>:Has:+> Habit(action=action, typical_amount=amount, hour_from=hour_from, hour_to=hour_to, count=count, label=label);
}

"""The usual monthly life of an elder: bills, pharmacy, pension. Largest usual payment = electricity."""
def add_elder_habits(c: Citizen, electricity: int, water: int, pharmacy: int, pension: int) {
    add_habit(c, "BILL_PAY", "Electricity bill", electricity, 9, 17, 36);
    add_habit(c, "BILL_PAY", "Water bill", water, 9, 17, 36);
    add_habit(c, "BILL_PAY", "Pharmacy", pharmacy, 8, 18, 24);
    add_habit(c, "WITHDRAW", "Pension withdrawal", pension, 9, 12, 60);
}

"""Story people + 20 normal citizens. Returns every personal account by id."""
def seed_people(banks: dict[str, Bank], places: dict[str, Place]) -> dict[str, Account] {
    acc: dict[str, Account] = {};

    # Seeya: 74, retired teacher in Kandy. 35 years of savings in an FD for Nethmi's university fees.
    seeya = add_citizen("c_seeya", "Seeya Siriwardena", 74, "Kandy", "si", "Galaxy A12 (Android)", "2023-02", places);
    add_elder_habits(seeya, 6000, 3000, 5000, 40000);
    acc["LDB-20114"] = open_account(banks["LDB"], "LDB-20114", seeya.name, 9100, balance=185000, owner=seeya);
    acc["LDB-20115"] = open_account(banks["LDB"], "LDB-20115", seeya.name, 2900, balance=4200000, owner=seeya, is_fd=True);
    seeya +>:ProtectedBy:+> Guardian(id="g_dilshan", name="Dilshan Siriwardena", relation="son", language=Lang.SI);

    # Earlier victims today (no guardian on Rakshaka yet)
    mallika = add_citizen("c_mallika", "Mallika Gunawardena", 69, "Galle", "si", "Redmi 9 (Android)", "2022-08", places);
    add_elder_habits(mallika, 4500, 2500, 4000, 35000);
    acc["CDB-30871"] = open_account(banks["CDB"], "CDB-30871", mallika.name, 7300, balance=40000, owner=mallika);

    rasheed = add_citizen("c_rasheed", "Rasheed Mohamed", 71, "Kurunegala", "ta", "Galaxy A32 (Android)", "2021-11", places);
    add_elder_habits(rasheed, 5000, 2800, 6000, 38000);
    acc["IDB-41290"] = open_account(banks["IDB"], "IDB-41290", rasheed.name, 8200, balance=25000, owner=rasheed);

    # Kamala: 70, Trincomalee, Island Demo Bank, Tamil. Same scam call later (S4).
    kamala = add_citizen("c_kamala", "Kamala Thiruchelvam", 70, "Trincomalee", "ta", "Redmi 9 (Android)", "2022-05", places);
    add_elder_habits(kamala, 5000, 2500, 4000, 35000);
    acc["IDB-52230"] = open_account(banks["IDB"], "IDB-52230", kamala.name, 8800, balance=120000, owner=kamala);
    acc["IDB-52231"] = open_account(banks["IDB"], "IDB-52231", kamala.name, 2100, balance=2600000, owner=kamala, is_fd=True);
    kamala +>:ProtectedBy:+> Guardian(id="g_priya", name="Priya Thiruchelvam", relation="daughter", language=Lang.TA);

    # Bank fraud analyst (War Room)
    root ++> Analyst(id="an_fernando", name="Ms Fernando", language=Lang.EN);

    # 20 normal citizens with normal habits
    for (i, row) in enumerate(NORMAL_CITIZENS) {
        age = row["age"] as int;
        c = add_citizen(
            str(row["id"]), str(row["name"]), age, str(row["city"]), str(row["lang"]),
            PHONES[i % len(PHONES)], f"{2019 + i % 5}-{1 + i % 12:02d}", places
        );
        bill = row["bill"] as int;
        add_habit(c, "BILL_PAY", "Electricity bill", bill, 8, 20, 12 + i);
        add_habit(c, "BILL_PAY", "Supermarket", 6000 + (i * 731) % 9000, 8, 21, 40 + i);
        if age < 65 {
            add_habit(c, "TRANSFER", "Family transfer", 15000 + (i * 1300) % 20000, 9, 21, 10 + i % 7);
        }
        bank = str(row["bank"]);
        aid = normal_account_id(i);
        acc[aid] = open_account(banks[bank], aid, c.name, 400 + i * 211, balance=60000 + (i * 15731) % 900000, owner=c);
    }
    return acc;
}
