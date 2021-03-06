/***
  BEGIN LICENSE

  Copyright (C) 2014-2015 Nathan Dyer <mail@nathandyer.me>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses>

  END LICENSE
***/

using Gtk;
namespace Vocal {

    public class SearchResultsView : Gtk.Box {

        public signal void on_new_subscription(string url);
        public signal void return_to_library(); 

        public signal void episode_selected(Podcast podcast, Episode episode);
        public signal void podcast_selected(Podcast podcast);

        public Gtk.SearchEntry search_entry;

        private string search_term = "";

        private Gtk.Label title_label;
        private iTunesProvider itunes;

        private Gtk.ListBox     local_episodes_listbox;
        private Gtk.ListBox     local_podcasts_listbox;
        private Gtk.FlowBox     cloud_results_flowbox;

        private Gee.ArrayList<Widget> local_episodes_widgets;
        private Gee.ArrayList<Widget> local_podcasts_widgets;
        private Gee.ArrayList<Widget> cloud_results_widgets;

        private Gtk.Box content_box;
        private Gtk.Spinner spinner;

        private Library library;

        private Gtk.Label no_local_episodes_label;
        private Gtk.Label no_local_podcasts_label;

        /*
         * Constructor for the full search results view. Shows all matches from the local library and across the iTunes ecosystem
         */
        public SearchResultsView(Library library) {

            string query = "";
            this.set_orientation(Gtk.Orientation.VERTICAL);
            this.itunes = new iTunesProvider();
            this.library = library;

            var return_button = new Gtk.Button.with_label(_("Return to Library"));
            return_button.clicked.connect(() => { return_to_library (); });
            
            return_button.get_style_context().add_class("back-button");
            return_button.margin = 6;
            return_button.hexpand = true;
            return_button.halign = Gtk.Align.START;

            // Set up the title

            title_label = new Gtk.Label("");
            title_label.margin_top = 5;
            title_label.margin_bottom = 5;
            title_label.justify = Gtk.Justification.CENTER;
            title_label.expand = false;
            title_label.use_markup = true;
            Granite.Widgets.Utils.apply_text_style_to_label (Granite.TextStyle.H2, title_label);

            var local_episodes_label = new Gtk.Label(_("Episodes from Your Library"));
            var local_podcasts_label = new Gtk.Label(_("Podcasts from Your Library"));
            var cloud_results_label = new Gtk.Label(_("iTunes Podcast Results"));

            local_episodes_label.get_style_context().add_class("h3");
            local_episodes_label.set_property("xalign", 0);
            local_podcasts_label.get_style_context().add_class("h3");
            local_podcasts_label.set_property("xalign", 0);
            cloud_results_label.get_style_context().add_class("h3");
            cloud_results_label.set_property("xalign", 0);

            var iTunes_box = new  Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);
            spinner = new Gtk.Spinner();
            spinner.active = true;
            spinner.halign = Gtk.Align.START;
            iTunes_box.add(cloud_results_label);
            iTunes_box.add(spinner);

            var return_button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            return_button_box.homogeneous = true;
            return_button_box.get_style_context().add_class("toolbar");
            return_button_box.get_style_context().add_class("library-toolbar");
            return_button_box.add(return_button);

            search_entry = new Gtk.SearchEntry ();
            search_entry.valign = Gtk.Align.CENTER;
            search_entry.halign = Gtk.Align.CENTER;
            search_entry.max_width_chars = 40;
            search_entry.activate.connect (() => {
                this.search_term = search_entry.text;
                title_label.label = _("Search Results for <i>%s</i>".printf(search_term));
                reset ();
                load_from_itunes ();
                load_local_results ();
            });
            return_button_box.add (search_entry);
            return_button_box.add (new Gtk.Label (""));

            this.add(return_button_box);
            this.add(title_label);

            // Create the lists container
            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            var scrolled = new Gtk.ScrolledWindow(null, null);
            content_box.add(title_label);
            scrolled.add(content_box);
            this.add(scrolled);

            local_episodes_listbox = new Gtk.ListBox();
            local_podcasts_listbox = new Gtk.ListBox();
            cloud_results_flowbox = new Gtk.FlowBox();

            local_episodes_listbox.activate_on_single_click = true;
            local_podcasts_listbox.activate_on_single_click = true;

            local_episodes_listbox.button_press_event.connect(on_episode_activated);
            local_podcasts_listbox.button_press_event.connect(on_podcast_activated);
            local_episodes_listbox.expand = true;
            local_podcasts_listbox.expand = true;
            cloud_results_flowbox.expand = true;

            local_episodes_widgets = new Gee.ArrayList<Widget>();
            local_podcasts_widgets = new Gee.ArrayList<Widget>();
            cloud_results_widgets = new Gee.ArrayList<Widget>();
            
            no_local_episodes_label = new Gtk.Label (_("No matching episodes found in your library."));
            no_local_podcasts_label = new Gtk.Label (_("No matching podcasts found in your library."));
            no_local_episodes_label.halign = Gtk.Align.CENTER;
            no_local_podcasts_label.halign = Gtk.Align.CENTER;
            no_local_episodes_label.get_style_context ().add_class ("h3");
            no_local_podcasts_label.get_style_context ().add_class ("h3");

            content_box.add(local_podcasts_label);
            content_box.add(no_local_podcasts_label);
            content_box.add(local_podcasts_listbox);
            content_box.add(local_episodes_label);
            content_box.add(no_local_episodes_label);
            content_box.add(local_episodes_listbox);
            content_box.add(iTunes_box);
            content_box.add(cloud_results_flowbox);

            content_box.margin = 5;

            hide_spinner ();
            hide_no_local_podcasts ();
            hide_no_local_episodes ();
        }

        private void reset () {
            local_episodes_widgets.clear ();
            local_podcasts_widgets.clear ();
            cloud_results_widgets.clear ();

            foreach (Gtk.Widget a in local_episodes_listbox.get_children ()) {
                local_episodes_listbox.remove (a);
            }
            foreach (Gtk.Widget b in local_podcasts_listbox.get_children ()) {
                local_podcasts_listbox.remove (b);
            }
            foreach (Gtk.Widget c in cloud_results_flowbox.get_children ()) {
                cloud_results_flowbox.remove (c);
            }
            show_all ();

        }

        /*
         * Loads the full list of iTunes store matches (popover limited to top 5 only, for both speed and size concerns)
         */
        private async void load_from_itunes() {

            SourceFunc callback = load_from_itunes.callback;
            show_spinner();

            ThreadFunc<void*> run = () => {
                Gee.ArrayList<DirectoryEntry> c_matches = itunes.search_by_term(search_term);
                foreach(DirectoryEntry c in c_matches) {
                    DirectoryArt a = new DirectoryArt(c.itunesUrl, c.title, c.artist, c.summary, c.artworkUrl600);
                    a.subscribe_button_clicked.connect((url) => {
                        on_new_subscription(url);
                    });
                    cloud_results_widgets.add(a);

                }

                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);

            yield;

            foreach(Widget w in cloud_results_widgets) {
                cloud_results_flowbox.add(w);
            }
            hide_spinner ();
            show_all();

        }

        /*
         * Loads episode and podcast results from the local library
         */
        private async void load_local_results () {

            SourceFunc callback = load_local_results.callback;
            Gee.ArrayList<Podcast> p_matches = new Gee.ArrayList<Podcast>();
            Gee.ArrayList<Episode> e_matches = new Gee.ArrayList<Episode>();

            ThreadFunc<void*> run = () => {

                if(search_term.length > 0) {

					p_matches.clear();
					p_matches.add_all(library.find_matching_podcasts(search_term));

					e_matches.clear();
					e_matches.add_all(library.find_matching_episodes(search_term));
				}


                Idle.add((owned) callback);
                return null;
            };
            Thread.create<void*>(run, false);

            yield;

            // Clear the current widgets


            // Actually load and show the results
            foreach(Podcast p in p_matches) {
                SearchResultBox srb = new SearchResultBox(p, null);
                local_podcasts_widgets.add(srb);
                local_podcasts_listbox.add(srb);
            }

            if(p_matches.size == 0) {
                show_no_local_podcasts ();
                hide_local_podcasts_listbox ();

            } else {
                hide_no_local_podcasts ();
                show_local_podcasts_listbox ();
            }

            foreach(Episode e in e_matches) {
                Podcast parent = null;
                foreach(Podcast p in library.podcasts) {
                    if(e.parent.name == p.name) {
                        parent = p;
                    }
                }
                SearchResultBox srb = new SearchResultBox(parent, e);
                local_episodes_widgets.add(srb);
                local_episodes_listbox.add(srb);
            }

            if(e_matches.size == 0) {
                show_no_local_episodes ();
                hide_local_episodes_listbox ();
            } else {
                hide_no_local_episodes ();
                show_local_episodes_listbox ();
            }
            show_all ();
        }

        /*
         * Called when a matching episode is selected by the user
         */
        private bool on_episode_activated(Gdk.EventButton button) {
            var row = local_episodes_listbox.get_row_at_y((int)button.y);
            int index = row.get_index();
            SearchResultBox selected = local_episodes_widgets[index] as SearchResultBox;
            episode_selected(selected.get_podcast(), selected.get_episode());
            return false;
        }

        /*
         * Called when a matching podcast is selected by the user
         */
        private bool on_podcast_activated(Gdk.EventButton button) {
            var row = local_podcasts_listbox.get_row_at_y((int)button.y);
            int index = row.get_index();
            SearchResultBox selected = local_podcasts_widgets[index] as SearchResultBox;
            podcast_selected(selected.get_podcast());
            return false;
        }

        private void hide_spinner () {
            spinner.no_show_all = true;
            spinner.hide ();
        }

        private void show_spinner () {
            spinner.no_show_all = false;
            spinner.show ();
        }

        private void show_no_local_episodes () {
            no_local_episodes_label.no_show_all = false;
            no_local_episodes_label.show ();
        }

        private void hide_no_local_episodes () {
            no_local_episodes_label.no_show_all = true;
            no_local_episodes_label.hide ();
        }

        private void show_no_local_podcasts () {
            no_local_podcasts_label.no_show_all = false;
            no_local_podcasts_label.show ();
        }

        private void hide_no_local_podcasts () {
            no_local_podcasts_label.no_show_all = true;
            no_local_podcasts_label.hide ();
        }

        private void hide_local_episodes_listbox () {
            local_episodes_listbox.no_show_all = true;
            local_episodes_listbox.hide ();
        }

        private void show_local_episodes_listbox () {
            local_episodes_listbox.no_show_all = false;
            local_episodes_listbox.show ();
        }

        private void hide_local_podcasts_listbox () {
            local_podcasts_listbox.no_show_all = true;
            local_podcasts_listbox.hide ();
        }

        private void show_local_podcasts_listbox () {
            local_podcasts_listbox.no_show_all = false;
            local_podcasts_listbox.show ();
        }
    }
}
