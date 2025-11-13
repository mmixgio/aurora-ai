import { Card } from "@/components/ui/card";
import { ScrollArea } from "@/components/ui/scroll-area";
import { FileText, Save } from "lucide-react";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";

interface OutputPanelProps {
  generatedText: string;
}

const OutputPanel = ({ generatedText }: OutputPanelProps) => {
  const handleSave = () => {
    if (!generatedText) {
      toast.error("No content to save");
      return;
    }

    const existingContent = localStorage.getItem('aurora-saved-content') || '';
    const timestamp = new Date().toLocaleString();
    const newContent = `\n\n--- Saved on ${timestamp} ---\n${generatedText}`;
    
    localStorage.setItem('aurora-saved-content', existingContent + newContent);
    toast.success("Content saved locally!");
  };

  const handleExport = () => {
    if (!generatedText) {
      toast.error("No content to export");
      return;
    }

    const blob = new Blob([generatedText], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `aurora-export-${Date.now()}.txt`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    toast.success("Content exported!");
  };

  return (
    <Card className="h-full flex flex-col shadow-md border border-border/50">
      <div className="p-4 border-b border-border/50 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <FileText className="h-5 w-5 text-primary" />
          <h3 className="text-lg font-semibold text-foreground">Output</h3>
        </div>
        <div className="flex gap-2">
          <Button
            onClick={handleSave}
            variant="outline"
            size="sm"
            className="border-border/50 hover:bg-secondary transition-all duration-300"
            disabled={!generatedText}
          >
            <Save className="h-4 w-4 mr-2" />
            Save
          </Button>
          <Button
            onClick={handleExport}
            variant="outline"
            size="sm"
            className="border-border/50 hover:bg-secondary transition-all duration-300"
            disabled={!generatedText}
          >
            Export
          </Button>
        </div>
      </div>
      
      <ScrollArea className="flex-1 p-6">
        {generatedText ? (
          <div className="prose prose-stone max-w-none">
            <p className="whitespace-pre-wrap text-foreground leading-relaxed">
              {generatedText}
            </p>
          </div>
        ) : (
          <div className="flex items-center justify-center h-full">
            <p className="text-muted-foreground text-center">
              Generated content will appear here...
            </p>
          </div>
        )}
      </ScrollArea>
    </Card>
  );
};

export default OutputPanel;