import { useState } from "react";
import Navbar from "@/components/Navbar";
import TextGenerator from "@/components/TextGenerator";
import ImageGenerator from "@/components/ImageGenerator";
import OutputPanel from "@/components/OutputPanel";

const Index = () => {
  const [generatedText, setGeneratedText] = useState("");

  const handleTextGenerated = (text: string) => {
    setGeneratedText(text);
  };

  const handleImageGenerated = (imageUrl: string) => {
    // Store image URL in localStorage for future reference
    const savedImages = JSON.parse(localStorage.getItem('aurora-images') || '[]');
    savedImages.push({ url: imageUrl, timestamp: new Date().toISOString() });
    localStorage.setItem('aurora-images', JSON.stringify(savedImages));
  };

  return (
    <div className="min-h-screen bg-background">
      <Navbar />
      
      <main className="container mx-auto px-8 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 h-[calc(100vh-8rem)]">
          {/* Left Panel - Input Section */}
          <div className="space-y-6 flex flex-col">
            <TextGenerator onTextGenerated={handleTextGenerated} />
            <ImageGenerator onImageGenerated={handleImageGenerated} />
          </div>

          {/* Right Panel - Output Section */}
          <div className="flex flex-col">
            <OutputPanel generatedText={generatedText} />
          </div>
        </div>
      </main>
    </div>
  );
};

export default Index;