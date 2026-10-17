# Seed: the 3 fictional banks + a helper to open accounts (A)
import from graph.nodes { Bank, Citizen, Account, AccountKind }
import from graph.edges { AccountAt, Owns }

# Fictional banks. Each one is a column on the War Room canvas.
glob BANKS: list[dict[str, str]] = [
    {"name": "Lanka Demo Bank", "short": "LDB"},
    {"name": "Ceylon Demo Bank", "short": "CDB"},
    {"name": "Island Demo Bank", "short": "IDB"}
];

"""Create the 3 banks on root. Returns them by short name."""
def seed_banks() -> dict[str, Bank] {
    banks: dict[str, Bank] = {};
    for row in BANKS {
        b = Bank(name=row["name"], short=row["short"]);
        root ++> b;
        banks[b.short] = b;
    }
    return banks;
}

"""Open an account at a bank, owned by a citizen if given."""
def open_account(
    bank: Bank,
    account_id: str,
    owner_name: str,
    opened_days_ago: int,
    kind: AccountKind = AccountKind.PERSONAL,
    balance: int = 0,
    owner: Citizen | None = None,
    is_fd: bool = False
) -> Account {
    a = Account(
        id=account_id,
        bank=bank.short,
        owner_name=owner_name,
        opened_days_ago=opened_days_ago,
        kind=kind,
        balance=balance,
        is_fd=is_fd
    );
    a +>:AccountAt:+> bank;
    if owner is not None {
        owner +>:Owns:+> a;
    }
    return a;
}
