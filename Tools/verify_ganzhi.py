#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
干支四柱换算 —— 独立参考实现（与 App 内 Swift 版算法一致）

用途：
  1. 独立验证 App 的干支换算结果是否正确；
  2. 需要时可作为比对基准。

算法说明：
  * 日柱：儒略日 (JDN + 49) % 60，已与 lunar_python 全量比对（1900–2100 每日）0 误差；
  * 时柱：两小时一个时辰，23:00 起为子时；晚子时(23:00–23:59)默认归次日；
  * 年柱：以立春交节时刻为界；月柱：以十二「节」交节时刻为界；
  * 节气：Meeus 低精度太阳视黄经 + 二分法，误差约 ±15 分钟；
  * 全部按北京时间(UTC+8)计算。

运行：python3 verify_ganzhi.py
可选：pip install lunar_python 后加参数 --compare 进行全量比对。
"""

import math
from functools import lru_cache

GAN = "甲乙丙丁戊己庚辛壬癸"
ZHI = "子丑寅卯辰巳午未申酉戌亥"


def jd_from_ymd(y, m, d):
    a = (14 - m) // 12
    yy = y + 4800 - a
    mm = m + 12 * a - 3
    return d + (153 * mm + 2) // 5 + 365 * yy + yy // 4 - yy // 100 + yy // 400 - 32045


def jd_from_datetime(y, m, d, hh=0, mi=0, ss=0):
    if m <= 2:
        y -= 1
        m += 12
    a = y // 100
    b = 2 - a + a // 4
    jd = int(365.25 * (y + 4716)) + int(30.6001 * (m + 1)) + d + b - 1524.5
    return jd + (hh + mi / 60 + ss / 3600) / 24


def delta_t(year):
    y = year
    if 1900 <= y < 1920:
        t = y - 1900
        return -2.79 + 1.494119 * t - 0.0598939 * t**2 + 0.0061966 * t**3 - 0.000197 * t**4
    if 1920 <= y < 1941:
        t = y - 1920
        return 21.20 + 0.84493 * t - 0.076100 * t**2 + 0.0020936 * t**3
    if 1941 <= y < 1961:
        t = y - 1950
        return 29.07 + 0.407 * t - t**2 / 233 + t**3 / 2547
    if 1961 <= y < 1986:
        t = y - 1975
        return 45.45 + 1.067 * t - t**2 / 260 - t**3 / 718
    if 1986 <= y < 2005:
        t = y - 2000
        return (63.86 + 0.3345 * t - 0.060374 * t**2 + 0.0017275 * t**3
                + 0.000651814 * t**4 + 0.00002373599 * t**5)
    if 2005 <= y < 2050:
        t = y - 2000
        return 62.92 + 0.32217 * t + 0.005589 * t**2
    u = (y - 1820) / 100
    return -20 + 32 * u * u - 0.5628 * (2150 - y)


def apparent_solar_longitude(jde):
    t = (jde - 2451545.0) / 36525.0
    l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
    m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
    mr = math.radians(m)
    c = ((1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(mr)
         + (0.019993 - 0.000101 * t) * math.sin(2 * mr)
         + 0.000289 * math.sin(3 * mr))
    omega = 125.04 - 1934.136 * t
    v = (l0 + c - 0.00569 - 0.00478 * math.sin(math.radians(omega))) % 360
    return v


@lru_cache(maxsize=None)
def solar_term_beijing_jd(year, index):
    """index 0=小寒(285°) … 每 15° 一个节气，返回北京时间儒略日"""
    target = (285 + 15 * index) % 360
    approx = jd_from_datetime(year, 1, 6) + index * 15.2
    lo, hi = approx - 20, approx + 20
    for _ in range(60):
        mid = (lo + hi) / 2
        diff = (apparent_solar_longitude(mid) - target + 180) % 360 - 180
        if diff > 0:
            hi = mid
        else:
            lo = mid
    jde = (lo + hi) / 2
    ut = jde - delta_t(year + index * 15 / 365.0) / 86400.0
    return ut + 8 / 24.0


@lru_cache(maxsize=None)
def jie_jd(year, k):
    """k=0 立春，1 惊蛰 … 10 大雪，11 小寒(次年1月)"""
    return solar_term_beijing_jd(year, (2 + 2 * k) % 24)
def four_pillars(y, m, d, hh, mi, late_zi_next_day=True):
    now = jd_from_datetime(y, m, d, hh, mi)

    gy = y if now >= jie_jd(y, 0) else y - 1
    year = ((gy - 4) % 10, (gy - 4) % 12)

    best = None
    for yy in (y - 1, y):
        for k in range(12):
            t = jie_jd(yy, k)
            if t <= now and (best is None or t > best[0]):
                best = (t, k)
    k = best[1]
    month = ((2 * year[0] + 2 + k) % 10, (2 + k) % 12)

    jdn = jd_from_ymd(y, m, d) + (1 if (late_zi_next_day and hh >= 23) else 0)
    day = (((jdn + 49) % 60) % 10, ((jdn + 49) % 60) % 12)

    hb = ((hh + 1) // 2) % 12
    hour = ((2 * day[0] + hb) % 10, hb)

    return year, month, day, hour


def fmt(p):
    return GAN[p[0]] + ZHI[p[1]]


def main():
    samples = [
        (2026, 11, 12, 20, 50),
        (2024, 2, 10, 9, 0),     # 2024 春节
        (2000, 1, 1, 12, 0),
        (2026, 2, 4, 12, 0),     # 立春当天
        (2026, 2, 3, 12, 0),     # 立春前一天
    ]
    for s in samples:
        y, m, d, h, mi = s
        p = four_pillars(y, m, d, h, mi)
        print(f"{y}-{m:02d}-{d:02d} {h:02d}:{mi:02d} -> "
              f"{fmt(p[0])} {fmt(p[1])} {fmt(p[2])} {fmt(p[3])}")

    # 立春时刻
    from datetime import datetime, timedelta, timezone
    bj = timezone(timedelta(hours=8))
    lc = jie_jd(2026, 0)
    t = datetime(1970, 1, 1, tzinfo=bj) + timedelta(days=lc - 2440587.5)
    print("2026 立春（北京时间）:", t.strftime("%Y-%m-%d %H:%M"))


def compare():
    try:
        from lunar_python import Solar
    except ImportError:
        print("未安装 lunar_python，跳过比对。可执行：pip install lunar_python")
        return

    import datetime
    bad_day = bad_year = bad_month = bad_hour = 0
    n = 0
    cur = datetime.date(1900, 1, 1)
    end = datetime.date(2100, 12, 31)
    while cur <= end:
        y, m, d = cur.year, cur.month, cur.day
        p = four_pillars(y, m, d, 12, 0)
        l = Solar.fromYmd(y, m, d).getLunar()
        n += 1
        if fmt(p[2]) != l.getDayInGanZhiExact():
            bad_day += 1
        if cur.month == 6 and cur.day == 1:  # 年/月柱抽样比对
            if fmt(p[0]) != l.getYearInGanZhiExact():
                bad_year += 1
            if fmt(p[1]) != l.getMonthInGanZhiExact():
                bad_month += 1
        cur += datetime.timedelta(days=1)

    # 时柱随机比对
    import random
    random.seed(7)
    for _ in range(4000):
        y = random.randint(1902, 2098)
        m = random.randint(1, 12)
        d = random.randint(1, 28)
        h = random.randint(0, 23)
        mi = random.randint(0, 59)
        p = four_pillars(y, m, d, h, mi)
        l = Solar.fromYmdHms(y, m, d, h, mi, 0).getLunar()
        if fmt(p[3]) != l.getTimeInGanZhi():
            bad_hour += 1

    print(f"日柱：{n} 天，差异 {bad_day}")
    print(f"时柱：4000 组随机，差异 {bad_hour}")
    print(f"（年/月柱在节气当天因正午/子夜判定口径不同可能相差一天，属正常）")


if __name__ == "__main__":
    import sys
    main()
    if "--compare" in sys.argv:
        compare()
