import toast, { Toast, ToastOptions } from 'react-hot-toast';
import { CheckCircle2, XCircle, AlertTriangle, Info } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

// Prava Palette Colors directly referenced for consistency
const COLORS = {
  success: '#3CCB7F',
  error: '#E5533D',
  warning: '#F4C430',
  info: '#5B8CFF',
  darkSurface: '#1D1D1D',
  lightSurface: '#FFFFFF',
  textLight: '#F2F2F2',
  textDark: '#0C0C0C',
};

interface SmartToastProps {
  t: Toast;
  type: 'success' | 'error' | 'warning' | 'info';
  message: string;
}

export const SmartToast = ({ t, type, message }: SmartToastProps) => {
  const icons = {
    success: <CheckCircle2 className="w-5 h-5 text-[#3CCB7F]" />,
    error: <XCircle className="w-5 h-5 text-[#E5533D]" />,
    warning: <AlertTriangle className="w-5 h-5 text-[#F4C430]" />,
    info: <Info className="w-5 h-5 text-[#5B8CFF]" />,
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: -20, scale: 0.9 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, scale: 0.9 }}
      className={`
        flex items-center gap-3 px-4 py-3 rounded-[16px] shadow-[0_8px_30px_rgba(0,0,0,0.12)]
        bg-white dark:bg-[#1D1D1D] border border-gray-100 dark:border-[#2E2E2E]
        min-w-[300px] backdrop-blur-md
      `}
    >
      <div className={`p-2 rounded-full bg-opacity-10 ${type === 'success' ? 'bg-[#3CCB7F]' :
        type === 'error' ? 'bg-[#E5533D]' :
          type === 'warning' ? 'bg-[#F4C430]' : 'bg-[#5B8CFF]'
        }`}>
        {icons[type]}
      </div>
      <div className="flex-1">
        <p className="text-sm font-semibold text-[#0C0C0C] dark:text-[#F2F2F2]">
          {message}
        </p>
      </div>
    </motion.div>
  );
};

export const smartToast = {
  success: (message: string, options?: ToastOptions) =>
    toast.custom((t) => <SmartToast t={t} type="success" message={message} />, options),
  error: (message: string, options?: ToastOptions) =>
    toast.custom((t) => <SmartToast t={t} type="error" message={message} />, options),
  warning: (message: string, options?: ToastOptions) =>
    toast.custom((t) => <SmartToast t={t} type="warning" message={message} />, options),
  info: (message: string, options?: ToastOptions) =>
    toast.custom((t) => <SmartToast t={t} type="info" message={message} />, options),
  dismiss: (toastId?: string) => toast.dismiss(toastId),
  dismissAll: () => toast.dismiss(),
};
