import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from 'recharts';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import LoadingSpinner from '@/components/common/LoadingSpinner';
import { useAppStore } from '@/stores/appStore';
import { companyQueryUrl, fetchCalc } from '@/lib/companyUtils';
import { fetchWithAuth } from '@/lib/api';
import { formatKRW, formatNumber, moduleLabel } from '@/lib/utils';
import type { SaleListItem } from '@/types/outbound';
import type { CustomerAnalysis, CustomerItem } from '@/hooks/useDashboard';

interface MarginItem {
  manufacturer_name: string;
  product_code: string;
  product_name: string;
  spec_wp: number;
  total_sold_qty: number;
  total_sold_kw: number;
  avg_sale_price_wp: number;
  avg_cost_wp?: number | null;
  margin_wp?: number | null;
  margin_rate?: number | null;
  total_revenue_krw: number;
  total_cost_krw?: number | null;
  total_margin_krw?: number | null;
  sale_count: number;
}

interface MarginAnalysis {
  items: MarginItem[];
  summary: {
    total_sold_kw: number;
    total_revenue_krw: number;
    total_cost_krw: number;
    total_margin_krw: number;
    overall_margin_rate: number;
    cost_basis: string;
  };
}

interface PageState {
  loading: boolean;
  error: string | null;
  sales: SaleListItem[];
  margin: MarginAnalysis | null;
  customers: CustomerAnalysis | null;
}

const emptyMargin: MarginAnalysis = {
  items: [],
  summary: {
    total_sold_kw: 0,
    total_revenue_krw: 0,
    total_cost_krw: 0,
    total_margin_krw: 0,
    overall_margin_rate: 0,
    cost_basis: 'landed',
  },
};

const emptyCustomers: CustomerAnalysis = {
  items: [],
  summary: {
    total_sales_krw: 0,
    total_collected_krw: 0,
    total_outstanding_krw: 0,
    total_margin_krw: 0,
    overall_margin_rate: 0,
  },
};

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

function mergeMargin(results: MarginAnalysis[]): MarginAnalysis {
  const map = new Map<string, MarginItem>();
  for (const result of results) {
    for (const item of result.items || []) {
      const key = `${item.manufacturer_name}|${item.product_code}|${item.spec_wp}`;
      const prev = map.get(key);
      if (!prev) {
        map.set(key, { ...item });
        continue;
      }
      const totalQty = prev.total_sold_qty + item.total_sold_qty;
      const totalRevenue = prev.total_revenue_krw + item.total_revenue_krw;
      const totalCost = (prev.total_cost_krw ?? 0) + (item.total_cost_krw ?? 0);
      const hasCost = prev.total_cost_krw != null || item.total_cost_krw != null;
      const totalMargin = hasCost ? totalRevenue - totalCost : null;
      const totalWp = totalQty * item.spec_wp;
      map.set(key, {
        ...prev,
        total_sold_qty: totalQty,
        total_sold_kw: prev.total_sold_kw + item.total_sold_kw,
        avg_sale_price_wp: totalWp > 0 ? round2(totalRevenue / totalWp) : 0,
        avg_cost_wp: hasCost && totalWp > 0 ? round2(totalCost / totalWp) : null,
        margin_wp: hasCost && totalWp > 0 ? round2((totalRevenue - totalCost) / totalWp) : null,
        margin_rate: totalRevenue > 0 && hasCost ? round2(((totalRevenue - totalCost) / totalRevenue) * 100) : null,
        total_revenue_krw: totalRevenue,
        total_cost_krw: hasCost ? totalCost : null,
        total_margin_krw: totalMargin,
        sale_count: prev.sale_count + item.sale_count,
      });
    }
  }
  const items = Array.from(map.values()).sort((a, b) => b.total_revenue_krw - a.total_revenue_krw);
  const totalRevenue = items.reduce((sum, item) => sum + item.total_revenue_krw, 0);
  const totalCost = items.reduce((sum, item) => sum + (item.total_cost_krw ?? 0), 0);
  const totalMargin = totalRevenue - totalCost;
  return {
    items,
    summary: {
      total_sold_kw: round2(items.reduce((sum, item) => sum + item.total_sold_kw, 0)),
      total_revenue_krw: round2(totalRevenue),
      total_cost_krw: round2(totalCost),
      total_margin_krw: round2(totalMargin),
      overall_margin_rate: totalRevenue > 0 ? round2((totalMargin / totalRevenue) * 100) : 0,
      cost_basis: results[0]?.summary.cost_basis ?? 'landed',
    },
  };
}

function mergeCustomers(results: CustomerAnalysis[]): CustomerAnalysis {
  const map = new Map<string, CustomerItem>();
  for (const result of results) {
    for (const item of result.items || []) {
      const prev = map.get(item.customer_id);
      if (!prev) {
        map.set(item.customer_id, { ...item });
        continue;
      }
      map.set(item.customer_id, {
        ...prev,
        total_sales_krw: prev.total_sales_krw + item.total_sales_krw,
        total_collected_krw: prev.total_collected_krw + item.total_collected_krw,
        outstanding_krw: prev.outstanding_krw + item.outstanding_krw,
        outstanding_count: prev.outstanding_count + item.outstanding_count,
        oldest_outstanding_days: Math.max(prev.oldest_outstanding_days, item.oldest_outstanding_days),
        total_margin_krw: (prev.total_margin_krw ?? 0) + (item.total_margin_krw ?? 0),
        avg_margin_rate: null,
      });
    }
  }
  const items = Array.from(map.values()).sort((a, b) => b.total_sales_krw - a.total_sales_krw);
  const totalSales = items.reduce((sum, item) => sum + item.total_sales_krw, 0);
  const totalMargin = items.reduce((sum, item) => sum + (item.total_margin_krw ?? 0), 0);
  return {
    items: items.map((item) => ({
      ...item,
      avg_margin_rate: item.total_sales_krw > 0 && item.total_margin_krw != null
        ? round2((item.total_margin_krw / item.total_sales_krw) * 100)
        : item.avg_margin_rate,
    })),
    summary: {
      total_sales_krw: totalSales,
      total_collected_krw: items.reduce((sum, item) => sum + item.total_collected_krw, 0),
      total_outstanding_krw: items.reduce((sum, item) => sum + item.outstanding_krw, 0),
      total_margin_krw: totalMargin,
      overall_margin_rate: totalSales > 0 ? round2((totalMargin / totalSales) * 100) : 0,
    },
  };
}

function toMonth(date?: string): string {
  return date ? date.slice(0, 7) : '날짜 없음';
}

export default function SalesAnalysisPage() {
  const selectedCompanyId = useAppStore((s) => s.selectedCompanyId);
  const [state, setState] = useState<PageState>({
    loading: true,
    error: null,
    sales: [],
    margin: null,
    customers: null,
  });

  const load = useCallback(async () => {
    if (!selectedCompanyId) {
      setState({ loading: false, error: null, sales: [], margin: null, customers: null });
      return;
    }
    setState((prev) => ({ ...prev, loading: true, error: null }));
    try {
      const [sales, margin, customers] = await Promise.all([
        fetchWithAuth<SaleListItem[]>(companyQueryUrl('/api/v1/sales', selectedCompanyId)),
        fetchCalc<MarginAnalysis>(
          selectedCompanyId,
          '/api/v1/calc/margin-analysis',
          { cost_basis: 'landed' },
          mergeMargin,
        ).catch(() => emptyMargin),
        fetchCalc<CustomerAnalysis>(
          selectedCompanyId,
          '/api/v1/calc/customer-analysis',
          { cost_basis: 'landed' },
          mergeCustomers,
        ).catch(() => emptyCustomers),
      ]);
      setState({ loading: false, error: null, sales, margin, customers });
    } catch (err) {
      setState((prev) => ({
        ...prev,
        loading: false,
        error: err instanceof Error ? err.message : '매출/이익 분석 데이터를 불러오지 못했습니다',
      }));
    }
  }, [selectedCompanyId]);

  useEffect(() => { load(); }, [load]);

  const monthly = useMemo(() => {
    const map = new Map<string, { month: string; revenue: number; vat: number; total: number; count: number }>();
    for (const item of state.sales) {
      const month = toMonth(item.outbound_date ?? item.order_date);
      const prev = map.get(month) ?? { month, revenue: 0, vat: 0, total: 0, count: 0 };
      prev.revenue += item.sale.supply_amount ?? 0;
      prev.vat += item.sale.vat_amount ?? 0;
      prev.total += item.sale.total_amount ?? 0;
      prev.count += 1;
      map.set(month, prev);
    }
    return Array.from(map.values()).sort((a, b) => a.month.localeCompare(b.month)).slice(-12);
  }, [state.sales]);

  const salesSummary = useMemo(() => {
    const supply = state.sales.reduce((sum, item) => sum + (item.sale.supply_amount ?? 0), 0);
    const total = state.sales.reduce((sum, item) => sum + (item.sale.total_amount ?? 0), 0);
    const issued = state.sales.filter((item) => item.sale.tax_invoice_date).length;
    return {
      supply,
      total,
      count: state.sales.length,
      issued,
      pending: state.sales.length - issued,
      issueRate: state.sales.length > 0 ? Math.round((issued / state.sales.length) * 100) : 0,
    };
  }, [state.sales]);

  const margin = state.margin ?? emptyMargin;
  const customers = state.customers ?? emptyCustomers;

  if (!selectedCompanyId) {
    return <div className="p-6 text-sm text-muted-foreground">좌측 상단에서 법인을 선택해주세요.</div>;
  }

  if (state.loading) return <LoadingSpinner className="h-full" />;

  return (
    <div className="p-6 space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-lg font-semibold">매출/이익 분석</h1>
          <p className="text-xs text-muted-foreground">판매, 세금계산서, 수금, BL 원가를 연결한 실무 분석 화면</p>
        </div>
        <button type="button" className="text-xs text-muted-foreground hover:text-foreground" onClick={load}>
          새로고침
        </button>
      </div>

      {state.error && (
        <div className="rounded-md border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive">
          {state.error}
        </div>
      )}

      <div className="grid grid-cols-2 gap-3 xl:grid-cols-6">
        <KpiCard label="공급가 매출" value={formatKRW(salesSummary.supply)} sub={`${formatNumber(salesSummary.count)}건`} />
        <KpiCard label="부가세 포함" value={formatKRW(salesSummary.total)} sub="세금계산서 기준 합계" />
        <KpiCard label="계산서 발행률" value={`${salesSummary.issueRate}%`} sub={`${formatNumber(salesSummary.issued)}건 발행 / ${formatNumber(salesSummary.pending)}건 미발행`} />
        <KpiCard label="수금액" value={formatKRW(customers.summary.total_collected_krw)} sub="거래처 분석 기준" />
        <KpiCard label="미수금" value={formatKRW(customers.summary.total_outstanding_krw)} sub="수금매칭 잔액 기준" />
        <KpiCard label="이익률" value={`${margin.summary.overall_margin_rate.toFixed(1)}%`} sub={formatKRW(margin.summary.total_margin_krw)} />
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1.1fr_0.9fr]">
        <Card>
          <CardHeader className="py-3">
            <CardTitle className="text-sm">월별 매출</CardTitle>
          </CardHeader>
          <CardContent>
            {monthly.length === 0 ? (
              <div className="flex h-[300px] items-center justify-center text-sm text-muted-foreground">매출 데이터가 없습니다</div>
            ) : (
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={monthly}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="month" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 10 }} tickFormatter={(v: number) => `${Math.round(v / 100000000)}억`} />
                  <Tooltip formatter={(value, name) => [formatKRW(Number(value)), name === 'revenue' ? '공급가' : '부가세 포함']} />
                  <Bar dataKey="revenue" fill="#2563eb" name="공급가" />
                  <Bar dataKey="total" fill="#16a34a" name="부가세 포함" />
                </BarChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="py-3">
            <CardTitle className="text-sm">거래처별 청구/미수</CardTitle>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>거래처</TableHead>
                  <TableHead className="text-right">청구액</TableHead>
                  <TableHead className="text-right">미수</TableHead>
                  <TableHead className="text-right">이익률</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {customers.items.slice(0, 8).map((item) => (
                  <TableRow key={item.customer_id}>
                    <TableCell className="text-xs font-medium">{item.customer_name}</TableCell>
                    <TableCell className="text-right text-xs">{formatKRW(item.total_sales_krw)}</TableCell>
                    <TableCell className="text-right text-xs">{formatKRW(item.outstanding_krw)}</TableCell>
                    <TableCell className="text-right text-xs">{item.avg_margin_rate != null ? `${item.avg_margin_rate.toFixed(1)}%` : '—'}</TableCell>
                  </TableRow>
                ))}
                {customers.items.length === 0 && (
                  <TableRow><TableCell colSpan={4} className="py-8 text-center text-xs text-muted-foreground">거래처 분석 데이터가 없습니다</TableCell></TableRow>
                )}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader className="py-3">
          <CardTitle className="text-sm">품목별 이익 분석</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>모듈</TableHead>
                <TableHead>품번 / 품명</TableHead>
                <TableHead className="text-right">수량</TableHead>
                <TableHead className="text-right">판매가</TableHead>
                <TableHead className="text-right">원가</TableHead>
                <TableHead className="text-right">이익/Wp</TableHead>
                <TableHead className="text-right">이익률</TableHead>
                <TableHead className="text-right">매출</TableHead>
                <TableHead className="text-right">이익</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {margin.items.map((item) => (
                <TableRow key={`${item.manufacturer_name}-${item.product_code}-${item.spec_wp}`}>
                  <TableCell className="text-xs font-medium">{moduleLabel(item.manufacturer_name, item.spec_wp)}</TableCell>
                  <TableCell className="text-xs">
                    <div className="font-medium">{item.product_code}</div>
                    <div className="text-muted-foreground">{item.product_name}</div>
                  </TableCell>
                  <TableCell className="text-right text-xs">{formatNumber(item.total_sold_qty)}</TableCell>
                  <TableCell className="text-right text-xs">{formatNumber(item.avg_sale_price_wp)}원</TableCell>
                  <TableCell className="text-right text-xs">{item.avg_cost_wp != null ? `${formatNumber(item.avg_cost_wp)}원` : '—'}</TableCell>
                  <TableCell className="text-right text-xs">{item.margin_wp != null ? `${formatNumber(item.margin_wp)}원` : '—'}</TableCell>
                  <TableCell className="text-right text-xs font-medium">{item.margin_rate != null ? `${item.margin_rate.toFixed(1)}%` : '—'}</TableCell>
                  <TableCell className="text-right text-xs">{formatKRW(item.total_revenue_krw)}</TableCell>
                  <TableCell className="text-right text-xs font-medium">{item.total_margin_krw != null ? formatKRW(item.total_margin_krw) : '—'}</TableCell>
                </TableRow>
              ))}
              {margin.items.length === 0 && (
                <TableRow><TableCell colSpan={9} className="py-8 text-center text-xs text-muted-foreground">이익 분석 데이터가 없습니다</TableCell></TableRow>
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}

function KpiCard({ label, value, sub }: { label: string; value: string; sub: string }) {
  return (
    <Card>
      <CardContent className="py-3">
        <p className="text-[10px] text-muted-foreground">{label}</p>
        <p className="mt-1 text-lg font-bold tracking-tight">{value}</p>
        <p className="mt-1 text-[10px] text-muted-foreground">{sub}</p>
      </CardContent>
    </Card>
  );
}
