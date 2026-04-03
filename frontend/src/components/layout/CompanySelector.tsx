import { useEffect } from 'react';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useAppStore } from '@/stores/appStore';

export default function CompanySelector() {
  const companies = useAppStore((s) => s.companies);
  const loadCompanies = useAppStore((s) => s.loadCompanies);
  const { selectedCompanyId, setCompanyId } = useAppStore();

  useEffect(() => {
    loadCompanies();
  }, [loadCompanies]);

  return (
    <Select value={selectedCompanyId || 'all'} onValueChange={(v) => setCompanyId(v)}>
      <SelectTrigger className="h-8 w-40 text-xs">
        <SelectValue placeholder="법인 선택" />
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
