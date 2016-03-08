require 'nokogiri'		# to rewrite the XLIFF file
require 'colorize'		# colorful console output
require 'digest/sha1'
require_relative 'models'
require_relative 'xcproj'

module Fame
	# Handles import and export of .xliff files
	class XLIFF

		def initialize(xcproj_path)
			@xcproj = XCProj(xcproj_path)
		end

		#
		# Imports all .xliff files at the given path into the current Xcode project
		# @param path A folder of .xliff files that should be imported into the current Xcode project.
		#
		def import(path)

		end

		#
		# Exports all .xliff files for the current Xcode project
		# @param path A path to a folder where exported .xliff files should be placed.
		# @param ib_nodes An array of `LocalizedNode`s, generated from `InterfaceBuilder.nodes`.
		#
		def export(path, ib_nodes)
			# export localizations
			export_xliffs(path)

			# update translation units based on the settings provided in Interface Builder
			# Localizations are only exported if explicitly enabled via the fame Interface Builder integration (see Fame.swift file).
			update_translation_units(path, ib_nodes)
		end

		private

		#
		# Exports all .xliff files for the current Xcode project to the given path.
		# @param path A path to a folder where exported .xliff files should be placed.
		#
		def export_xliffs(path)
			# get all languages that should be exported to separate .xliff files
			languages = @xcproj.all_languages
				.map { |l| "-exportLanguage #{l}" }
				.join(" ")

			`xcodebuild -exportLocalizations -localizationPath #{path} -project #{@xcproj.xcproj_path} #{languages}`
		end

		#
		# Modifies all .xliff files based on the settings extracted from Interface Builder nodes.
		#
		def update_xliff_translation_units(path, ib_nodes)
			@xcproj.all_languages.each do |language|
				xliff_path = File.join(path, "#{language}.xliff")
				puts "Updating translation units for #{language}".blue

				# Read XLIFF file
				raise "File #{xliff_path} does not exist" unless File.exists? xliff_path
				doc = read_xliff_file(xliff_path)

				# Extract all translation units from the xliff
				trans_units = doc.xpath('//xmlns:trans-unit')

				# Loop over the Interface Builder nodes and update the xliff file based on their settings
				ib_nodes.each do |ib_node|
					# Select nodes connected to original_id
					units = trans_units
						.map { |u| u["id"] rescue nil }
						.compact
						.select { |u| u.include?(ib_node.original_id) }

					# Update or remove nodes
					units.each do |unit|
						if ib_node.i18n_enabled
							# Update comment
							comment = unit.xpath("xmlns:note")
							comment.children.first.content = ib_node.formatted_info
						else
							# Remove translation unit, since it should not be translated
							unit.remove
						end
					end

					# Print status
					if nodes.count > 0
						status = ib_node.i18n_enabled ? "updated".green : "removed".red
						puts "  ✔︎ ".green + "#{nodes.count} translation unit(s) ".black + status + " for #{ib_node.original_id} ".black + "#{ib_node.formatted_info}".light_black
					end
				end

				# Write updated XLIFF file to disk
				write_xliff_file(doc, xliff_path)
			end
		end

		#
		# Reads the document at the given path and parses it into a `Nokogiri` XML doc.
		# @param path The path the xliff file that should be parsed
		# @return [Nokogiri::XML] A `Nokogiri` XML document representing the xliff
		#
		def read_xliff_file(path)
			xliff = File.open(xliff_path)
			doc = Nokogiri::XML(xliff)
			xliff.close

			doc
		end

		#
		# Writes the given `Nokogiri` doc to the given path
		# @param doc A Nokogiri XML document
		# @param path The path the `doc` should be written to
		#
		def write_xliff_file(doc, path)
			file = File.open(path, "w")
			doc.write_xml_to(file)
			file.close
		end

		#
		# The temporary folder to store generated .xliff files
		#
		# def tmp_folder
		# 	@tmp_folder =|| File.join("/tmp/com.aschuch.fame", Digest::SHA1.hexdigest(@xcproj.xcproj_path))
		# end
	end
end
