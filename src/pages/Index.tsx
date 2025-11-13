import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import Navbar from "@/components/Navbar";
import TextGenerator from "@/components/TextGenerator";
import ImageGenerator from "@/components/ImageGenerator";
import OutputPanel from "@/components/OutputPanel";
import { supabase } from "@/integrations/supabase/client";
import type { User as SupabaseUser } from "@supabase/supabase-js";

const Index = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<SupabaseUser | null>(null);
  const [generatedText, setGeneratedText] = useState("");

  useEffect(() => {
    // Check if user is logged in
    const checkUser = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        navigate("/auth");
        return;
      }
      setUser(session.user);
    };
    checkUser();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (!session) {
        navigate("/auth");
      } else {
        setUser(session.user);
      }
    });

    return () => subscription.unsubscribe();
  }, [navigate]);

  const handleTextGenerated = (text: string) => {
    setGeneratedText(text);
  };

  const handleImageGenerated = (imageUrl: string) => {
    // Store image URL in localStorage for future reference
    const savedImages = JSON.parse(localStorage.getItem('aurora-images') || '[]');
    savedImages.push({ url: imageUrl, timestamp: new Date().toISOString() });
    localStorage.setItem('aurora-images', JSON.stringify(savedImages));
  };

  if (!user) {
    return null; // Show nothing while checking auth
  }

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