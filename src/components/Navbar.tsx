import { Sparkles } from "lucide-react";

const Navbar = () => {
  return (
    <nav className="border-b border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 sticky top-0 z-50">
      <div className="container flex h-16 items-center px-8">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-primary to-primary-hover shadow-md">
            <Sparkles className="h-5 w-5 text-primary-foreground" />
          </div>
          <span className="text-xl font-semibold tracking-tight text-foreground">Aurora</span>
        </div>
        
        <div className="ml-auto">
          <span className="text-sm text-muted-foreground font-medium">AI Creative Workspace</span>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;