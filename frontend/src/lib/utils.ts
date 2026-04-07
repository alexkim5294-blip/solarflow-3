import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// --- 포맷 유틸 ---

export function formatNumber(n: number): string {
  return n.toLocaleString('ko-KR');
}

export function formatUSD(n: number): string {
  return `$${n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export function formatKRW(n: number): string {
  return `${n.toLocaleString('ko-KR')}원`;
}

export function formatPercent(n: number): string {
  return `${n.toFixed(2)}%`;
}

export function formatDate(d: string): string {
  if (!d) return '—';
  return d.slice(0, 10);
}

export function formatWp(n: number): string {
  return `${n}Wp`;
}

/**
 * kW 값을 "X.XMW (X,XXXkW)" 형식으로 통일 표시.
 * 용량 표기 = MW 기본 + kW 부수. EA는 알 수 있는 경우 formatCapacity로 추가.
 */
export function formatKw(n: number): string {
  const mw = (n / 1000).toFixed(1);
  const kw = Math.round(n).toLocaleString('ko-KR');
  return `${mw}MW (${kw}kW)`;
}

/**
 * kW + EA(모듈 장수) 함께 표시: "X.XMW (X,XXXkW / X,XXXEA)"
 * ea가 주어지지 않으면 formatKw와 동일.
 */
export function formatCapacity(kw: number, ea?: number): string {
  const base = formatKw(kw);
  if (ea == null || ea === 0) return base;
  return `${base.slice(0, -1)} / ${Math.round(ea).toLocaleString('ko-KR')}EA)`;
}

export function formatMW(n: number): string {
  return `${(n / 1000).toFixed(1)}MW`;
}

export function formatSize(w: number, h: number): string {
  return `${w} x ${h} mm`;
}
