import { useState, useEffect, useMemo } from 'react';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Select, SelectContent, SelectItem, SelectTrigger } from '@/components/ui/select';

function FT({ text }: { text: string }) {
  return <span className="flex flex-1 text-left truncate" data-slot="select-value">{text}</span>;
}
import { Alert, AlertDescription } from '@/components/ui/alert';
import { AlertTriangle } from 'lucide-react';
import { useAppStore } from '@/stores/appStore';
import { useInventory } from '@/hooks/useInventory';
import { useForecast } from '@/hooks/useForecast';
import { fetchWithAuth } from '@/lib/api';
import LoadingSpinner from '@/components/common/LoadingSpinner';
import InventorySummaryCards from '@/components/inventory/InventorySummaryCards';
import InventoryTable from '@/components/inventory/InventoryTable';
import IncomingTable from '@/components/inventory/IncomingTable';
import ForecastTable from '@/components/inventory/ForecastTable';
import type { Manufacturer } from '@/types/masters';

export default function InventoryPage() {
  const selectedCompanyId = useAppStore((s) => s.selectedCompanyId);
  const [manufacturers, setManufacturers] = useState<Manufacturer[]>([]);
  const [mfgFilter, setMfgFilter] = useState<string>('');
  const [wpFilter, setWpFilter] = useState<string>('');

  useEffect(() => {
    fetchWithAuth<Manufacturer[]>('/api/v1/manufacturers')
      .then((list) => setManufacturers(list.filter((m) => m.is_active)))
      .catch(() => {});
  }, []);

  const invOpts = mfgFilter ? { manufacturerId: mfgFilter } : {};
  const { data: rawInv, loading: invLoading, error: invError } = useInventory(invOpts);
  const { data: fcData, loading: fcLoading, error: fcError } = useForecast(invOpts);

  // 제조사 선택 시 해당 제조사 재고의 규격(Wp) 목록 추출
  const availableWps = useMemo(() => {
    if (!rawInv || !mfgFilter) return [];
    const set = new Set<number>();
    rawInv.items.forEach((it) => { if (it.spec_wp) set.add(it.spec_wp); });
    return [...set].sort((a, b) => a - b);
  }, [rawInv, mfgFilter]);

  // 제조사 변경 시 규격 필터 초기화
  useEffect(() => { setWpFilter(''); }, [mfgFilter]);

  // 규격 필터 적용
  const invData = useMemo(() => {
    if (!rawInv) return null;
    if (!wpFilter) return rawInv;
    const wp = parseFloat(wpFilter);
    return { ...rawInv, items: rawInv.items.filter((it) => it.spec_wp === wp) };
  }, [rawInv, wpFilter]);

  if (!selectedCompanyId) {
    return (
      <div className="flex items-center justify-center p-12">
        <p className="text-muted-foreground">좌측 상단에서 법인을 선택해주세요</p>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold">재고 현황</h1>
        <div className="flex gap-2">
          <Select value={mfgFilter || 'all'} onValueChange={(v) => setMfgFilter(v === 'all' ? '' : (v ?? ''))}>
            <SelectTrigger className="h-8 w-40 text-xs">
              <FT text={mfgFilter ? (manufacturers.find(m => m.manufacturer_id === mfgFilter)?.name_kr ?? '') : '제조사'} />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">제조사 (전체)</SelectItem>
              {manufacturers.map((m) => (
                <SelectItem key={m.manufacturer_id} value={m.manufacturer_id}>{m.name_kr}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select value={wpFilter || 'all'} onValueChange={(v) => setWpFilter(v === 'all' ? '' : (v ?? ''))}>
            <SelectTrigger className="h-8 w-32 text-xs" disabled={!mfgFilter}>
              <FT text={wpFilter ? `${wpFilter}Wp` : '규격'} />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">규격 (전체)</SelectItem>
              {availableWps.map((wp) => (
                <SelectItem key={wp} value={String(wp)}>{wp}Wp</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      <Tabs defaultValue="avail">
        <TabsList>
          <TabsTrigger value="avail">가용재고</TabsTrigger>
          <TabsTrigger value="incoming">미착품</TabsTrigger>
          <TabsTrigger value="stock">재고상세</TabsTrigger>
          <TabsTrigger value="forecast">수급 전망</TabsTrigger>
        </TabsList>

        {/* 가용재고 — 4 요약카드 + 모듈 크기mm + 물리/예약/배정/가용 */}
        <TabsContent value="avail">
          {invError && (
            <Alert variant="destructive" className="mb-3">
              <AlertTriangle className="h-4 w-4" />
              <AlertDescription>{invError}</AlertDescription>
            </Alert>
          )}
          {invLoading ? <LoadingSpinner /> : invData && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                <div className="rounded-md border p-3"><div className="text-[10px] text-muted-foreground">물리 MW</div><div className="text-sm font-semibold">{(invData.summary.total_physical_kw / 1000).toFixed(2)}</div></div>
                <div className="rounded-md border p-3"><div className="text-[10px] text-muted-foreground">가용 MW</div><div className="text-sm font-semibold">{(invData.summary.total_available_kw / 1000).toFixed(2)}</div></div>
                <div className="rounded-md border p-3"><div className="text-[10px] text-muted-foreground">미착품 MW</div><div className="text-sm font-semibold">{(invData.summary.total_incoming_kw / 1000).toFixed(2)}</div></div>
                <div className="rounded-md border p-3"><div className="text-[10px] text-muted-foreground">총 확보 MW</div><div className="text-sm font-semibold">{(invData.summary.total_secured_kw / 1000).toFixed(2)}</div></div>
              </div>
              <div className="rounded-md border overflow-x-auto">
                <table className="text-xs w-full">
                  <thead className="bg-muted/50"><tr>
                    <th className="text-left p-2">제조사</th>
                    <th className="text-left p-2">모델명</th>
                    <th className="text-left p-2">규격(Wp)</th>
                    <th className="text-left p-2">크기(mm)</th>
                    <th className="text-right p-2">물리 EA</th>
                    <th className="text-right p-2">물리 MW</th>
                    <th className="text-right p-2">예약 MW</th>
                    <th className="text-right p-2">배정 MW</th>
                    <th className="text-right p-2">가용 EA</th>
                    <th className="text-right p-2">가용 MW</th>
                  </tr></thead>
                  <tbody>
                    {invData.items.map((it) => {
                      const physicalEa = it.spec_wp > 0 ? Math.round((it.physical_kw * 1000) / it.spec_wp) : 0;
                      const availEa = it.spec_wp > 0 ? Math.round((it.available_kw * 1000) / it.spec_wp) : 0;
                      return (
                        <tr key={it.product_id} className="border-t">
                          <td className="p-2">{it.manufacturer_name}</td>
                          <td className="p-2">{it.product_name}</td>
                          <td className="p-2">{it.spec_wp}Wp</td>
                          <td className="p-2">{it.module_width_mm}x{it.module_height_mm}</td>
                          <td className="p-2 text-right">{physicalEa.toLocaleString()}</td>
                          <td className="p-2 text-right">{(it.physical_kw / 1000).toFixed(2)}</td>
                          <td className="p-2 text-right">{(it.reserved_kw / 1000).toFixed(2)}</td>
                          <td className="p-2 text-right">{(it.allocated_kw / 1000).toFixed(2)}</td>
                          <td className="p-2 text-right">{availEa.toLocaleString()}</td>
                          <td className="p-2 text-right font-semibold">{(it.available_kw / 1000).toFixed(2)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </TabsContent>

        <TabsContent value="stock">
          {invError && (
            <Alert variant="destructive" className="mb-3">
              <AlertTriangle className="h-4 w-4" />
              <AlertDescription>{invError}</AlertDescription>
            </Alert>
          )}
          {invLoading ? <LoadingSpinner /> : invData && (
            <div className="space-y-4">
              <InventorySummaryCards summary={invData.summary} />
              <InventoryTable items={invData.items} />
              <p className="text-[10px] text-muted-foreground text-right">계산 시점: {invData.calculated_at}</p>
            </div>
          )}
        </TabsContent>

        <TabsContent value="incoming">
          {invError && (
            <Alert variant="destructive" className="mb-3">
              <AlertTriangle className="h-4 w-4" />
              <AlertDescription>{invError}</AlertDescription>
            </Alert>
          )}
          {invLoading ? <LoadingSpinner /> : invData && (
            <IncomingTable items={invData.items} summary={invData.summary} />
          )}
        </TabsContent>

        <TabsContent value="forecast">
          {fcError && (
            <Alert variant="destructive" className="mb-3">
              <AlertTriangle className="h-4 w-4" />
              <AlertDescription>{fcError}</AlertDescription>
            </Alert>
          )}
          {fcLoading ? <LoadingSpinner /> : fcData && (
            <div className="space-y-2">
              <ForecastTable products={fcData.products} />
              <p className="text-[10px] text-muted-foreground text-right">계산 시점: {fcData.calculated_at}</p>
            </div>
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}
