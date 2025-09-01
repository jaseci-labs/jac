import React from 'react';
import { Moon, Sun, Github, FileText, Users } from 'lucide-react';
import { useTheme } from './ThemeProvider';
import { Button } from './ui/button';

export const Header: React.FC = () => {
  const { theme, toggleTheme } = useTheme();

  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background/80 backdrop-blur-sm">
      <div className="container flex h-16 items-center justify-between">
        <div className="flex items-center space-x-8">
          <div className="flex items-center space-x-2">
            <div className="h-8 w-8 rounded-lg bg-primary flex items-center justify-center">
              <span className="text-primary-foreground font-bold text-sm">BL</span>
            </div>
            <span className="text-xl font-semibold">By LLM</span>
          </div>
          
          <nav className="hidden md:flex items-center space-x-6">
            <a href="#install" className="text-muted-foreground hover:text-foreground transition-colors">
              Install
            </a>
            <a href="#documentation" className="text-muted-foreground hover:text-foreground transition-colors">
              Learn
            </a>
            <a href="#examples" className="text-muted-foreground hover:text-foreground transition-colors">
              Examples
            </a>
            <a href="#community" className="text-muted-foreground hover:text-foreground transition-colors">
              Community
            </a>
          </nav>
        </div>

        <div className="flex items-center space-x-2">
          <Button
            variant="ghost"
            size="sm"
            onClick={toggleTheme}
            className="h-9 w-9 p-0"
          >
            {theme === 'light' ? (
              <Moon className="h-4 w-4" />
            ) : (
              <Sun className="h-4 w-4" />
            )}
          </Button>
          <Button variant="ghost" size="sm" className="h-9 w-9 p-0">
            <Github className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </header>
  );
};