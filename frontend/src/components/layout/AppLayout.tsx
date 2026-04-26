import { Outlet } from 'react-router-dom';
import TopNav from './TopNav';
import FloatingMwEaCalculator from '@/components/common/FloatingMwEaCalculator';

export default function AppLayout() {
  return (
    <div className="flex h-screen min-h-0 flex-col bg-muted/25">
      <TopNav />
      <main className="min-h-0 flex-1 overflow-y-auto overflow-x-hidden">
        <Outlet />
      </main>
      {/* 전역 MW↔장수 계산기 (모든 보호 페이지에서 우하단 플로팅) */}
      <FloatingMwEaCalculator />
    </div>
  );
}
