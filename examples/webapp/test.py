#!/usr/bin/env python3
# type: ignore
import os
import pytest
import webengine

class Main(webengine.Thread):
    action_delay_seconds = .025

    def main(self):
        self.load('http://localhost:8000')

        # wait for homepage to load
        self.wait_for_attr('button.menu-button', 'innerText', ['home', 'other'])

        # prod builds use name mangling, the js api is for dev tests only
        name_mangling = self.js("window.frontend === undefined")

        # wipe state
        if not name_mangling:
            self.js('frontend.state_wipe()')
        self.wait_for_attr('span#value', 'innerText', ['0'])

        # click other
        self.click('button#other')
        self.wait_for_attr('div#content', 'innerText', ['other page'])

        # click home
        self.click('button#home')
        self.wait_for_attr('span#value', 'innerText', ['0'])

        # click increment
        self.click('button#value')
        self.wait_for_attr('span#value', 'innerText', ['2'])

        # click increment
        self.click('button#value')
        self.wait_for_attr('span#value', 'innerText', ['4'])

        # data survives page reload and auto increments on page load
        self.load('http://localhost:8000')
        self.wait_for_attr('span#value', 'innerText', ['6'])

        if not name_mangling:
            # reset db state
            self.js('frontend.state_wipe()')
            self.wait_for_attr('span#value', 'innerText', ['0'])

def test():
    webengine.run_thread(Main, devtools='horizontal')

if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    pytest.main(['test.py', '-svvx', '--tb', 'native'])
