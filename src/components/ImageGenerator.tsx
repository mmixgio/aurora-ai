import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card } from "@/components/ui/card";
import { ImageIcon, Loader2, Download } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";

interface ImageGeneratorProps {
  onImageGenerated: (imageUrl: string) => void;
}

const ImageGenerator = ({ onImageGenerated }: ImageGeneratorProps) => {
  const [prompt, setPrompt] = useState("");
  const [isGenerating, setIsGenerating] = useState(false);
  const [generatedImage, setGeneratedImage] = useState<string | null>(null);

  const handleGenerate = async () => {
    if (!prompt.trim()) {
      toast.error("Please enter a description");
      return;
    }

    setIsGenerating(true);

    try {
      const { data, error } = await supabase.functions.invoke('generate-image', {
        body: { prompt }
      });

      if (error) throw error;

      if (data?.imageUrl) {
        setGeneratedImage(data.imageUrl);
        onImageGenerated(data.imageUrl);
        toast.success("Image generated successfully!");
      } else {
        throw new Error("No image generated");
      }
    } catch (error: any) {
      console.error('Image generation error:', error);
      toast.error(error.message || "Failed to generate image");
    } finally {
      setIsGenerating(false);
    }
  };

  const handleDownload = () => {
    if (!generatedImage) return;
    
    const link = document.createElement('a');
    link.href = generatedImage;
    link.download = `aurora-generated-${Date.now()}.png`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    toast.success("Image download started!");
  };

  return (
    <Card className="p-6 space-y-4 shadow-md border border-border/50">
      <div className="flex items-center gap-2 mb-2">
        <ImageIcon className="h-5 w-5 text-primary" />
        <h3 className="text-lg font-semibold text-foreground">Image Generator</h3>
      </div>
      
      <Input
        placeholder="Describe the image you want to create..."
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
        onKeyPress={(e) => e.key === 'Enter' && !isGenerating && handleGenerate()}
        className="border-border/50 focus:border-primary transition-colors"
      />
      
      <Button 
        onClick={handleGenerate}
        disabled={isGenerating}
        className="w-full bg-primary hover:bg-primary-hover text-primary-foreground transition-all duration-300 shadow-sm hover:shadow-md"
      >
        {isGenerating ? (
          <>
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            Generating...
          </>
        ) : (
          <>
            <ImageIcon className="mr-2 h-4 w-4" />
            Generate Image
          </>
        )}
      </Button>

      {generatedImage && (
        <div className="space-y-3 pt-4 border-t border-border/50">
          <img 
            src={generatedImage} 
            alt="Generated" 
            className="w-full rounded-lg shadow-md border border-border/50"
          />
          <Button 
            onClick={handleDownload}
            variant="outline"
            className="w-full border-border/50 hover:bg-secondary transition-all duration-300"
          >
            <Download className="mr-2 h-4 w-4" />
            Download Image
          </Button>
        </div>
      )}
    </Card>
  );
};

export default ImageGenerator;