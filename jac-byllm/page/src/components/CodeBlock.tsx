import React, { useState } from 'react';
import { Copy, Check } from 'lucide-react';
import { Button } from './ui/button';

interface CodeBlockProps {
  code: string;
  language?: string;
  className?: string;
}

export const CodeBlock: React.FC<CodeBlockProps> = ({ 
  code, 
  language = 'bash',
  className = '' 
}) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className={`relative group bg-[hsl(var(--code-bg))] rounded-lg overflow-hidden ${className}`}>
      <div className="flex items-center justify-between px-4 py-2 border-b border-white/10">
        <span className="text-sm text-[hsl(var(--code-comment))] font-mono">{language}</span>
        <Button
          onClick={handleCopy}
          variant="ghost"
          size="sm"
          className="h-6 w-6 p-0 opacity-60 hover:opacity-100 text-white hover:text-white hover:bg-white/10"
        >
          {copied ? (
            <Check className="h-3 w-3" />
          ) : (
            <Copy className="h-3 w-3" />
          )}
        </Button>
      </div>
      <pre className="p-4 overflow-x-auto">
        <code className="text-[hsl(var(--code-text))] font-mono text-sm leading-relaxed">
          {code}
        </code>
      </pre>
    </div>
  );
};