# Seed: billers, the mule chain, Perera Hardware, normal payments and the canvas layout - all fictional (A)
import from graph.nodes { Bank, Citizen, Account, AccountKind }
import from graph.edges { AccountAt, Paid }
import from seed.banks { open_account }
import from seed.people { NORMAL_CITIZENS, normal_account_id }
import from operator { attrgetter }

# Story elders first, then by id (a named function: Jac 0.34 cannot run block lambdas inside a def).
def _seed_order(c: Citizen) -> tuple {
    return (0 if c.id in ["c_seeya", "c_mallika", "c_rasheed", "c_kamala"] else 1, c.id);
}

# The scam money chain, in order: first mule -> second -> third -> ATM cash-out.
glob MULE_CHAIN: list[str] = ["LDB-77821", "CDB-40213", "IDB-90077", "ATM-IDB-0042"];

# War Room canvas (about 1000 x 600): people left, banks as 3 columns, ATM cash-out right.
glob BANK_COLUMN_X: dict[str, int] = {"LDB": 360, "CDB": 560, "IDB": 760};
glob CHAIN_Y: int = 300;

"""One money movement between two accounts."""
def pay(src: Account, dst: Account, amount: int, at_time: str, days_ago: int = 0) {
    src +>:Paid(amount=amount, time=at_time, days_ago=days_ago):+> dst;
}

"""Billers, shops, hospital, mule chain and every payment. Adds the new accounts to acc."""
def seed_money(banks: dict[str, Bank], acc: dict[str, Account]) {
    # Billers, shops, hospital (old, trusted accounts)
    acc["LDB-10001"] = open_account(banks["LDB"], "LDB-10001", "Electricity Board", 12000, AccountKind.BILLER);
    acc["CDB-10002"] = open_account(banks["CDB"], "CDB-10002", "Water Board", 12000, AccountKind.BILLER);
    acc["IDB-10003"] = open_account(banks["IDB"], "IDB-10003", "City Supermarket", 5400, AccountKind.BILLER);
    acc["LDB-10004"] = open_account(banks["LDB"], "LDB-10004", "Kandy General Hospital", 15000, AccountKind.HOSPITAL);
    acc["LDB-10005"] = open_account(banks["LDB"], "LDB-10005", "Osu Pharmacy Kandy", 3300, AccountKind.SHOP);
    acc["IDB-10006"] = open_account(banks["IDB"], "IDB-10006", "Trinco Pharmacy", 2700, AccountKind.SHOP);
    # Decoy legit shop: 3 years old, steady daily sales. Also got Rs 12,000 from a mule (innocent).
    acc["CDB-11502"] = open_account(banks["CDB"], "CDB-11502", "Perera Hardware", 1100, AccountKind.SHOP, balance=2350000);

    # Mule chain (fictional holders)
    acc["LDB-77821"] = open_account(banks["LDB"], "LDB-77821", "K. Ranaweera", 9, AccountKind.MULE_SUSPECT);
    acc["CDB-40213"] = open_account(banks["CDB"], "CDB-40213", "S. Pathirana", 6, AccountKind.MULE_SUSPECT, balance=650000);
    acc["IDB-90077"] = open_account(banks["IDB"], "IDB-90077", "M. Rajapaksha", 4, AccountKind.MULE_SUSPECT);
    acc["ATM-IDB-0042"] = open_account(banks["IDB"], "ATM-IDB-0042", "ATM cash-out (Island Demo Bank)", 4, AccountKind.ATM_CASHOUT);
    # S2 thief's account (new, not flagged yet) and S4's new mule (nobody has paid it yet)
    acc["CDB-63390"] = open_account(banks["CDB"], "CDB-63390", "D. Kulatunga", 3);
    acc["IDB-31877"] = open_account(banks["IDB"], "IDB-31877", "T. Wijesekara", 2);

    # Today's scam money: Mallika 1:55 PM, Rasheed 2:10 PM
    pay(acc["CDB-30871"], acc["LDB-77821"], 650000, "13:55");
    pay(acc["LDB-77821"], acc["CDB-40213"], 650000, "14:05");     # Mallika's money - still at CDB-40213
    pay(acc["IDB-41290"], acc["LDB-77821"], 380000, "14:10");
    pay(acc["LDB-77821"], acc["CDB-40213"], 380000, "14:14");     # Rasheed's money moves on ...
    pay(acc["CDB-40213"], acc["IDB-90077"], 380000, "14:17");
    pay(acc["IDB-90077"], acc["ATM-IDB-0042"], 368000, "14:21");  # ... cashed out - lost
    pay(acc["IDB-90077"], acc["CDB-11502"], 12000, "14:22");      # small buy at an innocent shop

    # Seeya's normal life (savings LDB-20114)
    seeya = acc["LDB-20114"];
    pay(seeya, acc["LDB-10001"], 5800, "10:20", 30);
    pay(seeya, acc["LDB-10001"], 5400, "11:05", 60);
    pay(seeya, acc["LDB-10001"], 6000, "10:40", 90);
    pay(seeya, acc["CDB-10002"], 2900, "10:25", 32);
    pay(seeya, acc["CDB-10002"], 3000, "09:50", 62);
    pay(seeya, acc["LDB-10005"], 4200, "16:10", 12);
    pay(seeya, acc["LDB-10005"], 7800, "15:30", 40);
    pay(seeya, acc["LDB-10004"], 15000, "11:00", 150);

    # Kamala's normal life (savings IDB-52230)
    kamala = acc["IDB-52230"];
    pay(kamala, acc["LDB-10001"], 4800, "10:00", 28);
    pay(kamala, acc["CDB-10002"], 2500, "10:10", 30);
    pay(kamala, acc["IDB-10006"], 3500, "17:20", 10);

    # Mallika and Rasheed's normal bills
    pay(acc["CDB-30871"], acc["LDB-10001"], 4300, "09:40", 27);
    pay(acc["IDB-41290"], acc["LDB-10001"], 4900, "10:30", 29);

    # 20 normal citizens: bills, supermarket, Perera Hardware sales, family transfers
    for i in range(len(NORMAL_CITIZENS)) {
        mine = acc[normal_account_id(i)];
        bill = NORMAL_CITIZENS[i]["bill"] as int;
        pay(mine, acc["LDB-10001"], bill, f"{9 + i % 8:02d}:{(i * 7) % 60:02d}", 3 + i % 25);
        pay(mine, acc["IDB-10003"], 2000 + (i * 731) % 9000, f"{10 + i % 9:02d}:{(i * 13) % 60:02d}", i % 4);
        if i % 5 != 4 {
            pay(mine, acc["CDB-11502"], 1500 + (i * 977) % 7500, f"{8 + i % 10:02d}:{(i * 11) % 60:02d}", i % 3);
        }
        if i % 5 == 0 {
            other = acc[normal_account_id(i + 1)];
            pay(mine, other, 10000 + i * 750, "19:30", 7);
        }
    }
}

"""Give every Citizen and Account an x / y on the War Room canvas (about 1000 x 600)."""
def layout_canvas(banks: dict[str, Bank]) {
    # People on the left: 2 columns, story elders first
    people = sorted([root -->[?:Citizen]], key=_seed_order);
    for (i, c) in enumerate(people) {
        c.x = 50 + (i % 2) * 100;
        c.y = 40 + (i // 2) * 45;
    }
    pos = account_positions(list(banks.values()));
    for b in banks.values() {
        for a in [b <-:AccountAt:<-] {
            if a.id in pos {
                a.x = pos[a.id][0];
                a.y = pos[a.id][1];
            }
        }
    }
}

"""x / y of every account: banks as 3 columns, the mule chain on one row so the money trail reads left to right.
A pure function of the graph, so the War Room view can also use it (positions set on accounts during a reset
were not always saved by the server - see graph/views.jac)."""
def account_positions(banks: list[Bank]) -> dict[str, list[int]] {
    out: dict[str, list[int]] = {};
    rows = [y for y in range(40, 580, 42) if abs(y - CHAIN_Y) > 30];
    for b in banks {
        col = BANK_COLUMN_X[b.short];
        others = sorted([a for a in [b <-:AccountAt:<-] if a.id not in MULE_CHAIN], key=attrgetter("id"));
        for (j, a) in enumerate(others) {
            out[a.id] = [col - 45 + (j % 2) * 90, rows[(j // 2) % len(rows)]];
        }
    }
    xs = [BANK_COLUMN_X["LDB"], BANK_COLUMN_X["CDB"], BANK_COLUMN_X["IDB"], 940];
    for (k, aid) in enumerate(MULE_CHAIN) {
        out[aid] = [xs[k], CHAIN_Y];
    }
    return out;
}
