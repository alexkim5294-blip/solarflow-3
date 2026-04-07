import { Badge } from '@/components/ui/badge';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { formatKw, formatWp, formatSize } from '@/lib/utils';
import EmptyState from '@/components/common/EmptyState';
import type { InventoryItem } from '@/types/inventory';

function LongTermBadge({ status }: { status: string }) {
  if (status === 'warning') return <Badge variant="outline" className="border-yellow-500 text-yellow-600 text-[10px]">장기(6M+)</Badge>;
  if (status === 'critical') return <Badge variant="destructive" className="text-[10px]">초장기(12M+)</Badge>;
  return null;
}

export default function InventoryTable({ items }: { items: InventoryItem[] }) {
  if (items.length === 0) return <EmptyState message="등록된 재고 데이터가 없습니다" />;

  // 합계 행 — 물리적/미착품/가용 등 구성 분해를 한 눈에
  const totals = items.reduce(
    (acc, it) => ({
      physical: acc.physical + (it.physical_kw || 0),
      reserved: acc.reserved + (it.reserved_kw || 0),
      allocated: acc.allocated + (it.allocated_kw || 0),
      available: acc.available + (it.available_kw || 0),
      incoming: acc.incoming + (it.incoming_kw || 0),
      incomingReserved: acc.incomingReserved + (it.incoming_reserved_kw || 0),
      availableIncoming: acc.availableIncoming + (it.available_incoming_kw || 0),
      totalSecured: acc.totalSecured + (it.total_secured_kw || 0),
    }),
    { physical: 0, reserved: 0, allocated: 0, available: 0, incoming: 0, incomingReserved: 0, availableIncoming: 0, totalSecured: 0 },
  );

  return (
    <div className="rounded-md border overflow-x-auto">
      <Table className="text-xs">
        <TableHeader>
          <TableRow>
            <TableHead className="whitespace-nowrap">제조사</TableHead>
            <TableHead className="whitespace-nowrap">품번</TableHead>
            <TableHead className="whitespace-nowrap">품명</TableHead>
            <TableHead className="whitespace-nowrap text-right">규격</TableHead>
            <TableHead className="whitespace-nowrap text-right">크기</TableHead>
            <TableHead className="whitespace-nowrap text-right">물리적</TableHead>
            <TableHead className="whitespace-nowrap text-right">예약</TableHead>
            <TableHead className="whitespace-nowrap text-right">배정</TableHead>
            <TableHead className="whitespace-nowrap text-right">가용</TableHead>
            <TableHead className="whitespace-nowrap text-right">미착품</TableHead>
            <TableHead className="whitespace-nowrap text-right">미착예약</TableHead>
            <TableHead className="whitespace-nowrap text-right">가용미착</TableHead>
            <TableHead className="whitespace-nowrap text-right">총확보</TableHead>
            <TableHead className="whitespace-nowrap">장기재고</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {items.map((item) => (
            <TableRow key={item.product_id}>
              <TableCell className="whitespace-nowrap">{item.manufacturer_name}</TableCell>
              <TableCell className="whitespace-nowrap font-mono">{item.product_code}</TableCell>
              <TableCell className="whitespace-nowrap">{item.product_name}</TableCell>
              <TableCell className="text-right">{formatWp(item.spec_wp)}</TableCell>
              <TableCell className="text-right whitespace-nowrap">{formatSize(item.module_width_mm, item.module_height_mm)}</TableCell>
              <TableCell className="text-right font-medium">{formatKw(item.physical_kw)}</TableCell>
              <TableCell className="text-right">{formatKw(item.reserved_kw)}</TableCell>
              <TableCell className="text-right">{formatKw(item.allocated_kw)}</TableCell>
              <TableCell className="text-right font-medium text-green-600">{formatKw(item.available_kw)}</TableCell>
              <TableCell className="text-right">{formatKw(item.incoming_kw)}</TableCell>
              <TableCell className="text-right">{formatKw(item.incoming_reserved_kw)}</TableCell>
              <TableCell className="text-right">{formatKw(item.available_incoming_kw)}</TableCell>
              <TableCell className="text-right font-medium text-purple-600">{formatKw(item.total_secured_kw)}</TableCell>
              <TableCell><LongTermBadge status={item.long_term_status} /></TableCell>
            </TableRow>
          ))}
          <TableRow className="bg-muted/50 font-semibold border-t-2">
            <TableCell colSpan={5} className="text-right">합계</TableCell>
            <TableCell className="text-right">{formatKw(totals.physical)}</TableCell>
            <TableCell className="text-right">{formatKw(totals.reserved)}</TableCell>
            <TableCell className="text-right">{formatKw(totals.allocated)}</TableCell>
            <TableCell className="text-right text-green-600">{formatKw(totals.available)}</TableCell>
            <TableCell className="text-right">{formatKw(totals.incoming)}</TableCell>
            <TableCell className="text-right">{formatKw(totals.incomingReserved)}</TableCell>
            <TableCell className="text-right">{formatKw(totals.availableIncoming)}</TableCell>
            <TableCell className="text-right text-purple-600">{formatKw(totals.totalSecured)}</TableCell>
            <TableCell />
          </TableRow>
        </TableBody>
      </Table>
      <div className="px-3 py-2 text-[10px] text-muted-foreground border-t bg-muted/20">
        가용재고 구성: <span className="text-foreground">물리적({formatKw(totals.physical)})</span> − 확정사용({formatKw(totals.reserved + totals.allocated)}) = <span className="text-green-600">가용({formatKw(totals.available)})</span>
        <span className="mx-2">+</span>
        <span className="text-foreground">미착품({formatKw(totals.incoming)})</span> − 미착예약({formatKw(totals.incomingReserved)}) = 가용미착({formatKw(totals.availableIncoming)})
        <span className="mx-2">→</span>
        <span className="text-purple-600">총확보({formatKw(totals.totalSecured)})</span>
      </div>
    </div>
  );
}
