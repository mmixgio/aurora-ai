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
    <Card className="h-full glass-effect border-border/50 shadow-lg hover:shadow-xl animate-smooth">
      <CardHeader className="pb-4">
        <div className="flex items-center justify-between">
          <CardTitle className="flex items-center gap-2 text-2xl">
            <FileText className="h-5 w-5 text-primary" />
            Risultato
          </CardTitle>
          {generatedText && (
            <div className="flex gap-2">
              <Button 
                variant="outline" 
                size="sm" 
                onClick={handleSave}
                className="rounded-full hover:scale-105 animate-smooth"
              >
                <Save className="h-4 w-4 mr-2" />
                Salva
              </Button>
              <Button 
                variant="outline" 
                size="sm" 
                onClick={handleExport}
                className="rounded-full hover:scale-105 animate-smooth"
              >
                <Download className="h-4 w-4 mr-2" />
                Esporta
              </Button>
            </div>
          )}
        </div>
      </CardHeader>
      <CardContent className="flex-1 flex flex-col min-h-0">
        <ScrollArea className="flex-1 rounded-xl border border-border/50 p-6 bg-background/50 min-h-[300px]">
          {generatedText ? (
            <div className="whitespace-pre-wrap text-base leading-relaxed animate-fade-in">
              {generatedText}
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center h-full text-muted-foreground gap-3">
              <FileText className="h-12 w-12 opacity-20" />
              <p className="text-sm">Il testo generato apparirà qui</p>
            </div>
          )}
        </ScrollArea>
      </CardContent>
    </Card>
  );
};

export default OutputPanel;