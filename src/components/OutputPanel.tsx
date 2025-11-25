import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Download, Save, FileText } from "lucide-react";
import { toast } from "sonner";
import { ScrollArea } from "@/components/ui/scroll-area";

interface OutputPanelProps {
  generatedText: string;
}

const OutputPanel = ({ generatedText }: OutputPanelProps) => {
  const handleSave = () => {
    if (!generatedText) return;
    
    const savedTexts = JSON.parse(localStorage.getItem('aurora-texts') || '[]');
    savedTexts.push({
      text: generatedText,
      timestamp: new Date().toISOString()
    });
    localStorage.setItem('aurora-texts', JSON.stringify(savedTexts));
    toast.success("Testo salvato localmente!");
  };

  const handleExport = () => {
    if (!generatedText) return;
    
    const blob = new Blob([generatedText], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `aurora-text-${Date.now()}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    toast.success("Testo esportato!");
  };

  return (
    <Card className="h-full glass-effect border-border/50 shadow-lg hover:shadow-2xl transition-all duration-500 hover:border-primary/30 group">
      <CardHeader className="pb-3 sm:pb-4 space-y-1">
        <div className="flex items-center justify-between gap-3 flex-wrap">
          <CardTitle className="flex items-center gap-2 text-xl sm:text-2xl group-hover:text-primary transition-colors duration-300">
            <div className="p-2 rounded-lg bg-primary/10 group-hover:bg-primary/20 transition-all duration-300 group-hover:scale-110">
              <FileText className="h-4 w-4 sm:h-5 sm:w-5 text-primary" />
            </div>
            Risultato
          </CardTitle>
          {generatedText && (
            <div className="flex gap-2">
              <Button 
                variant="outline" 
                size="sm" 
                onClick={handleSave}
                className="rounded-full hover:scale-110 active:scale-95 transition-all duration-300 hover:bg-primary hover:text-primary-foreground text-xs sm:text-sm"
              >
                <Save className="h-3 w-3 sm:h-4 sm:w-4 sm:mr-2" />
                <span className="hidden sm:inline">Salva</span>
              </Button>
              <Button 
                variant="outline" 
                size="sm" 
                onClick={handleExport}
                className="rounded-full hover:scale-110 active:scale-95 transition-all duration-300 hover:bg-primary hover:text-primary-foreground text-xs sm:text-sm"
              >
                <Download className="h-3 w-3 sm:h-4 sm:w-4 sm:mr-2" />
                <span className="hidden sm:inline">Esporta</span>
              </Button>
            </div>
          )}
        </div>
      </CardHeader>
      <CardContent className="flex-1 flex flex-col min-h-0">
        <ScrollArea className="flex-1 rounded-xl border border-border/50 p-4 sm:p-6 bg-background/50 hover:bg-background/70 transition-colors duration-300 min-h-[300px] sm:min-h-[400px]">
          {generatedText ? (
            <div className="whitespace-pre-wrap text-sm sm:text-base leading-relaxed animate-fade-in">
              {generatedText}
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center h-full text-muted-foreground gap-3">
              <FileText className="h-10 w-10 sm:h-12 sm:w-12 opacity-20 group-hover:opacity-30 transition-opacity duration-300" />
              <p className="text-xs sm:text-sm">Il testo generato apparirà qui</p>
            </div>
          )}
        </ScrollArea>
      </CardContent>
    </Card>
  );
};

export default OutputPanel;