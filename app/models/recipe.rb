require "open-uri"

class Recipe < ApplicationRecord
  has_one_attached :photo

  # callback: appeler une fonction (ou des) a un certain moment de la vie d'une instance (avant/apres save, etc..)
  after_save if: -> { saved_change_to_name? || saved_change_to_ingredients? } do
    set_content
    set_photo
  end

  # super: appelle la methode par default (ici elle renvoie le contenu)
  def content
    if super.blank? # si la colonne est vide, remplis avec OPENAI
      set_content # genere du contenu avec l'OPENAI et renvoie ce nouveau contenu
    else
      super # sinon fais comme par default self.content (le contenu de la colonne)
    end
  end

  def set_content
    client = OpenAI::Client.new
    chaptgpt_response = client.chat(parameters: {
      model: "gpt-3.5-turbo",
      messages: [{ role: "user", content: "Give me a simple recipe for #{name} with the ingredients #{ingredients}. Give me only the text of the recipe, without any of your own answer like 'Here is a simple recipe'."}]
    })

    self.update(content: chaptgpt_response["choices"][0]["message"]["content"]) # renvoie true/false
    return content
  end

  def set_photo
    # 1. genere la photo avec OPENAI
    client = OpenAI::Client.new
    response = client.images.generate(parameters: {
      prompt: "A recipe image of #{name}", size: "256x256"
    })

    url = response["data"][0]["url"]

    # 2. Ouvre la photo / telecharge
    file = URI.open(url) # ouvrir l'url et obtenir la photo

    # 3. sauvegarde la photo dans cloudinary && associe la photo a la recette
    photo.purge if photo.attached? # supprime la photo si elle existe
    self.photo.attach(io: file, filename: "#{name}.png", content_type: "image/png")
    return photo
  end
end


#  cache = un hash ou chaque clé est évalue pour savoir si elle a changé
# si la clé a changé on recalcule la valeur, sinon on retourne la valeur deja stocké
# cache_key_with_version = version d'une instance. Si l'instance change, la clé
