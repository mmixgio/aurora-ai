import { Sparkles } from "lucide-react";

const Footer = () => {
  return (
    <footer className="w-full border-t border-border/40 mt-auto">
      <div className="container mx-auto px-6 py-8">
        <div className="flex flex-col items-center justify-center gap-4">
          <div className="flex items-center gap-2">
            <Sparkles className="h-5 w-5 text-muted-foreground" />
            <span className="text-sm font-medium text-muted-foreground">Aurora</span>
          </div>
          <p className="text-xs text-muted-foreground text-center">
            AI Creative Workspace - {new Date().getFullYear()}
          </p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
