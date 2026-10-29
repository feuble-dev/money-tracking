'use client';

import React from 'react';
import Link from 'next/link';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'accent' | 'outline' | 'outline-white' | 'danger' | 'ghost' | 'subtle';
  size?: 'sm' | 'md' | 'lg';
  href?: string;
  loading?: boolean;
  children: React.ReactNode;
}

const variants: Record<NonNullable<ButtonProps['variant']>, string> = {
  primary: 'bg-ink text-white hover:bg-primary-dark',
  accent: 'bg-accent text-white hover:bg-accent-hover',
  outline: 'border border-gray-300 bg-white text-dark hover:border-gray-400 hover:bg-gray-50',
  'outline-white': 'border border-white/40 text-white hover:bg-white/10',
  danger: 'bg-red-600 text-white hover:bg-red-700',
  ghost: 'text-gray-600 hover:bg-gray-100 hover:text-dark',
  subtle: 'bg-primary-50 text-primary hover:bg-primary-100',
};

const sizes: Record<NonNullable<ButtonProps['size']>, string> = {
  sm: 'h-8 px-3 text-xs gap-1.5',
  md: 'h-10 px-4 text-sm gap-2',
  lg: 'h-12 px-6 text-base gap-2',
};

export default function Button({
  variant = 'primary',
  size = 'md',
  href,
  loading = false,
  disabled,
  children,
  className = '',
  ...props
}: ButtonProps) {
  const classes = `inline-flex items-center justify-center rounded-lg font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40 disabled:cursor-not-allowed disabled:opacity-50 ${variants[variant]} ${sizes[size]} ${className}`;

  if (href) {
    return (
      <Link href={href} className={classes}>
        {children}
      </Link>
    );
  }
  return (
    <button className={classes} disabled={disabled || loading} {...props}>
      {loading && (
        <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-t-transparent" />
      )}
      {children}
    </button>
  );
}
