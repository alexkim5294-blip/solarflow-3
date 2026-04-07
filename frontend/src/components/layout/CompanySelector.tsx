import { useEffect } from 'react';
import { Select, SelectContent, SelectItem, SelectTrigger } from '@/components/ui/select';
import { useAppStore } from '@/stores/appStore';

function FT({ text }: { text: string }) {
  return <span className="flex flex-1 text-left truncate" data-slot="select-value">{text}</span>;
}

export default function CompanySelector() {
  const companies = useAppStore((s) => s.companies);
  const loadCompanies = useAppStore((s) => s.loadCompanies);
  const { selectedCompanyId, setCompanyId } = useAppStore();

  useEffect(() => {
    loadCompanies();
  }, [loadCompanies]);

  const label = !selectedCompanyId || selectedCompanyId === 'all'
    ? '전체'
    : (companies.find((c) => c.company_id === selectedCompanyId)?.company_name ?? '법인 선택');

  return (
    <Select value={selectedCompanyId || 'all'} onValueChange={(v) => setCompanyId(v)}>
      <SelectTrigger className="h-8 w-40 text-xs">
        <FT text={label} />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="all">전체</SelectItem>
        {companies.map((c) => (
          <SelectItem key={c.company_id} value={c.company_id}>
            {c.company_name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
