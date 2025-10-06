# File: scripts/make_charts.py
"""
Reads exports/*.csv and saves visuals to images/*.png for README use.
Run:  python scripts/make_charts.py
Requires: pandas, matplotlib
"""

from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

EXPORTS_DIR = Path("exports")
IMAGES_DIR = Path("images")
IMAGES_DIR.mkdir(parents=True, exist_ok=True)

def _fmt_currency():
    return FuncFormatter(lambda x, _: f"${x:,.0f}")

def _fmt_pct():
    return FuncFormatter(lambda x, _: f"{x:.0f}%")

def _csv_exists(name: str) -> bool:
    return (EXPORTS_DIR / name).exists()

def _read_csv(name: str) -> pd.DataFrame:
    p = EXPORTS_DIR / name
    return pd.read_csv(p)

def _ensure_numeric(df: pd.DataFrame, cols):
    for c in cols:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")
    return df

def rotate_xlabels(ax, rotation=45, ha="right"):
    # Needed because tick_params doesn't accept 'ha'
    for lbl in ax.get_xticklabels():
        lbl.set_rotation(rotation)
        lbl.set_ha(ha)

def chart_kpi_headline():
    if not _csv_exists("kpi_headline.csv"):
        print("skip: kpi_headline.csv missing")
        return
    df = _read_csv("kpi_headline.csv")
    row = df.iloc[0]
    orders = int(row.get("orders", 0) or 0)
    customers = int(row.get("customers", 0) or 0)
    products = int(row.get("products", 0) or 0)
    net_revenue = float(row.get("net_revenue", 0) or 0)
    aov = float(row.get("aov", 0) or 0)
    min_date = str(row.get("min_date", "") or "")
    max_date = str(row.get("max_date", "") or "")
    fig = plt.figure(figsize=(10, 5))
    fig.patch.set_facecolor("white")
    plt.axis("off")
    plt.text(0.02, 0.88, "E-commerce Sales — KPI Summary", fontsize=18, weight="bold")
    plt.text(0.02, 0.80, f"Date Range: {min_date} → {max_date}", fontsize=11)
    y0 = 0.55
    cards = [
        ("Net Revenue", f"${net_revenue:,.0f}"),
        ("Orders", f"{orders:,}"),
        ("Customers", f"{customers:,}"),
        ("Products", f"{products:,}"),
        ("AOV", f"${aov:,.2f}"),
    ]
    for i, (k, v) in enumerate(cards):
        x = 0.02 + i * 0.19
        plt.text(x, y0 + 0.06, k, fontsize=11)
        plt.text(x, y0, v, fontsize=20, weight="bold")
        plt.gca().add_patch(plt.Rectangle((x - 0.01, y0 - 0.02), 0.18, 0.14,
                                          fill=False, linewidth=1, transform=plt.gca().transAxes))
    plt.savefig(IMAGES_DIR / "kpi_dashboard.png", bbox_inches="tight", dpi=150)
    plt.close()

def chart_top_customers_ltv(top_n: int = 10):
    if not _csv_exists("top_customers_ltv.csv"):
        print("skip: top_customers_ltv.csv missing")
        return
    df = _read_csv("top_customers_ltv.csv")
    df = _ensure_numeric(df, ["ltv", "orders_count", "ltv_rank"])
    df = df.sort_values("ltv", ascending=False).head(top_n).iloc[::-1]
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.barh(df["customer_id"].astype(str), df["ltv"])
    ax.set_title("Top Customers by LTV")
    ax.set_xlabel("LTV (USD)")
    ax.xaxis.set_major_formatter(_fmt_currency())
    for i, v in enumerate(df["ltv"]):
        ax.text(v, i, f" ${v:,.0f}", va="center", ha="left", fontsize=9)
    plt.tight_layout()
    plt.savefig(IMAGES_DIR / "top_customers_ltv.png", dpi=150)
    plt.close()

def chart_sales_by_category():
    if not _csv_exists("sales_by_category.csv"):
        print("skip: sales_by_category.csv missing")
        return
    df = _read_csv("sales_by_category.csv")
    df = _ensure_numeric(df, ["orders", "revenue", "revenue_share_pct"])
    df = df.sort_values("revenue", ascending=False)
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.bar(df["product_category"].astype(str), df["revenue"])
    ax.set_title("Revenue by Product Category (USD)")
    ax.set_ylabel("Revenue")
    ax.yaxis.set_major_formatter(_fmt_currency())
    rotate_xlabels(ax, rotation=45, ha="right")
    for x, y, s in zip(df["product_category"], df["revenue"], df["revenue_share_pct"]):
        ax.text(x, y, f"{s:.1f}%", ha="center", va="bottom", fontsize=8)
    plt.tight_layout()
    plt.savefig(IMAGES_DIR / "sales_by_category.png", dpi=150)
    plt.close()

def chart_sales_by_region():
    if not _csv_exists("sales_by_region.csv"):
        print("skip: sales_by_region.csv missing")
        return
    df = _read_csv("sales_by_region.csv")
    df = _ensure_numeric(df, ["orders", "revenue", "revenue_share_pct"])
    df = df.sort_values("revenue", ascending=False)
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(df["region"].astype(str), df["revenue"])
    ax.set_title("Revenue by Region (USD)")
    ax.set_ylabel("Revenue")
    ax.yaxis.set_major_formatter(_fmt_currency())
    for x, y, s in zip(df["region"], df["revenue"], df["revenue_share_pct"]):
        ax.text(x, y, f"{s:.1f}%", ha="center", va="bottom", fontsize=9)
    plt.tight_layout()
    plt.savefig(IMAGES_DIR / "sales_by_region.png", dpi=150)
    plt.close()

def chart_seasonality_monthly():
    if not _csv_exists("seasonality_monthly.csv"):
        print("skip: seasonality_monthly.csv missing")
        return
    df = _read_csv("seasonality_monthly.csv")
    df = _ensure_numeric(df, ["year", "month", "orders", "revenue", "avg_order_value"])
    df["year"] = df["year"].astype(int)
    df["month"] = df["month"].astype(int)
    df["date"] = pd.to_datetime(dict(year=df["year"], month=df["month"], day=1))
    df = df.sort_values("date")
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(df["date"], df["revenue"])
    ax.set_title("Monthly Revenue Trend")
    ax.set_ylabel("Revenue (USD)")
    ax.yaxis.set_major_formatter(_fmt_currency())
    ax.grid(True, axis="y", linestyle="--", alpha=0.3)
    plt.tight_layout()
    plt.savefig(IMAGES_DIR / "seasonality_monthly.png", dpi=150)
    plt.close()

def chart_payment_mix():
    if not _csv_exists("payment_mix.csv"):
        print("skip: payment_mix.csv missing")
        return
    df = _read_csv("payment_mix.csv")
    df = _ensure_numeric(df, ["orders", "revenue", "aov", "revenue_share_pct"])
    df = df.sort_values("revenue", ascending=False)
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(df["payment_method"].astype(str), df["revenue"])
    ax.set_title("Payment Mix — Revenue & AOV")
    ax.set_ylabel("Revenue (USD)")
    ax.yaxis.set_major_formatter(_fmt_currency())
    for x, y, aov in zip(df["payment_method"], df["revenue"], df["aov"]):
        ax.text(x, y, f"AOV ${aov:,.0f}", ha="center", va="bottom", fontsize=9)
    plt.tight_layout()
    plt.savefig(IMAGES_DIR / "payment_mix.png", dpi=150)
    plt.close()

def chart_new_vs_repeat():
    if not _csv_exists("new_vs_repeat.csv"):
        print("skip: new_vs_repeat.csv missing")
        return
    df = _read_csv("new_vs_repeat.csv")
    df = _ensure_numeric(df, ["orders", "revenue", "orders_share_pct", "revenue_share_pct"])
    fig, ax = plt.subplots(figsize=(8, 5))
    new_row = df[df["customer_order_type"] == "new"]
    rep_row = df[df["customer_order_type"] == "repeat"]
    orders_new = float(new_row["orders_share_pct"]) if not new_row.empty else 0
    orders_rep = float(rep_row["orders_share_pct"]) if not rep_row.empty else 0
    rev_new = float(new_row["revenue_share_pct"]) if not new_row.empty else 0
    rev_rep = float(rep_row["revenue_share_pct"]) if not rep_row.empty else 0
    ax.bar(["Orders %"], [orders_new])
    ax.bar(["Orders %"], [orders_rep], bottom=[orders_new])
    ax.bar(["Revenue %"], [rev_new])
    ax.bar(["Revenue %"], [rev_rep], bottom=[rev_new])
    ax.set_title("New vs Repeat — Share of Orders & Revenue")
    ax.yaxis.set_major_formatter(_fmt_pct())
    ax.set_ylim(0, 100)
    for x, top, bottom in [("Orders %", orders_rep, orders_new), ("Revenue %", rev_rep, rev_new)]:
        ax.text(x, bottom/2, f"{bottom:.0f}%", ha="center", va="center", fontsize=9)
        ax.text(x, bottom + top/2, f"{top:.0f}%", ha="center", va="center", fontsize=9)
    plt.tight_layout()
    plt.savefig(IMAGES_DIR / "new_vs_repeat.png", dpi=150)
    plt.close()

def main():
    # Generate what’s available; skip missing files without crashing
    chart_kpi_headline()
    chart_top_customers_ltv()
    chart_sales_by_category()
    chart_sales_by_region()
    chart_seasonality_monthly()
    chart_payment_mix()
    chart_new_vs_repeat()
    print(f"Charts saved to: {IMAGES_DIR.resolve()}")

if __name__ == "__main__":
    main()
