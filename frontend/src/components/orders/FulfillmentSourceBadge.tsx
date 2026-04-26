import { cn } from '@/lib/utils';
import { FULFILLMENT_SOURCE_LABEL, FULFILLMENT_SOURCE_COLOR, type FulfillmentSource } from '@/types/orders';

export default function FulfillmentSourceBadge({ source }: { source?: FulfillmentSource | string | null }) {
  const knownSource = source === 'stock' || source === 'incoming' ? source : null;

  return (
    <span className={cn(
      'inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-medium',
      knownSource ? FULFILLMENT_SOURCE_COLOR[knownSource] : 'bg-slate-100 text-slate-600'
    )}>
      {knownSource ? FULFILLMENT_SOURCE_LABEL[knownSource] : '—'}
    </span>
  );
}
