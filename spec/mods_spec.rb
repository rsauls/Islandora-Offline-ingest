$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), '../lib'))
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))

require 'open3'
require 'helpers'
require 'offin/mods'

RSpec.describe Mods do

  include ModsHelpers

  describe "#new" do
    it "Correctly parses an example MODS file" do
      mods = Mods.new(config, test_data_path("FGCU100369398.MODS.xml"))

      expect(mods.valid?).to be == true
      expect(mods.title).to  be == 'Administration Building'
      expect(mods.errors).to be_empty
    end
  end

  describe "#new" do
    it "Correctly parses an example MODS file" do
      mods = Mods.new(config, test_data_path("FSU_Tablet_03.MODS.xml"))

      expect(mods.valid?).to        be == true
      expect(mods.title).to         be == 'FSU 03'
      expect(mods.iids.length).to   be == 1
      expect(mods.iids[0]).to       be == 'FSU_Tablet_03'
      expect(mods.errors).to        be_empty
    end
  end

  describe "#languages" do
    it "Correctly parses an example newpaper MODS file and extracts the language elements" do
      mods = Mods.new(config, test_data_path("newspaper.mods"))

      expect(mods.valid?).to             be == true
      expect(mods.languages.length).to   be == 1
      expect(mods.languages[0]).to       be == 'eng'
      expect(mods.errors).to             be_empty
    end
  end

  describe "#date_issued" do
    it "Correctly parses an example newpaper MODS file and extracts the w3cdtf dateIssued elements" do
      mods = Mods.new(config, test_data_path("newspaper.mods"))

      expect(mods.valid?).to               be == true
      expect(mods.date_issued.length).to   be == 1
      expect(mods.date_issued[0]).to       be == '1915-01-23'
      expect(mods.errors).to               be_empty
    end
  end


  # Huh.   We don't check IIDs there, then...

  # describe "#new" do
  #   it "Parses an example MODS file with IID issues, and correctly diagnoses it" do
  #     mods = Mods.new(config, test_data_path("FSU_Tablet_03_Bad.MODS.xml"))
  #
  #     expect(mods.valid?).to  be == true
  #     expect(mods.title).to   be == 'FSU 03'
  #     expect(mods.errors).to  be_empty
  #   end
  # end

end
