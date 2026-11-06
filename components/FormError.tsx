export function FormError({ message }: { message?: string | null }) {
  if (!message) return null;
  return (
    <div role="alert" className="rounded-[10px] border border-[#f0c7c2] bg-[#fdf1ef] px-3 py-2 text-sm text-bad">
      {message}
    </div>
  );
}
