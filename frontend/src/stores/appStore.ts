import { create } from 'zustand';
import { fetchWithAuth } from '@/lib/api';
import type { Company } from '@/types/masters';

interface AppState {
  selectedCompanyId: string | null;
  setCompanyId: (id: string | null) => void;
  sidebarCollapsed: boolean;
  toggleSidebar: () => void;
  companies: Company[];
  companiesLoaded: boolean;
  loadCompanies: () => Promise<void>;
}

let loadPromise: Promise<void> | null = null;

export const useAppStore = create<AppState>((set, get) => ({
  selectedCompanyId: 'all',
  setCompanyId: (id) => set({ selectedCompanyId: id }),
  sidebarCollapsed: false,
  toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
  companies: [],
  companiesLoaded: false,
  loadCompanies: () => {
    if (get().companiesLoaded) return Promise.resolve();
    if (loadPromise) return loadPromise;
    loadPromise = fetchWithAuth<Company[]>('/api/v1/companies')
      .then((list) => {
        set({ companies: list.filter((c) => c.is_active), companiesLoaded: true });
      })
      .catch((err) => {
        console.error('[appStore] companies 로딩 실패:', err);
      })
      .finally(() => {
        loadPromise = null;
      });
    return loadPromise;
  },
}));
