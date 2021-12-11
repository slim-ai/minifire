#!/usr/bin/env python3
# type: ignore
import sys
import time
import os
import pytest
import webengine

class Main(webengine.Thread):
    action_delay_seconds = .025

    def main(self):

        for _ in range(60):
            try:
                self.load('http://0.0.0.0:8000')
                self.wait_for_attr('button.menu-button', 'innerText', ['home', 'other'])

                # prod builds use name mangling, the js api is for dev tests only
                name_mangling = self.js("window.frontend === undefined")

                # wipe state
                if not name_mangling:
                    self.js('frontend.state_wipe()')

                self.wait_for_attr('span#value', 'innerText', ['0'])

            except:
                print('waiting for startup')
                time.sleep(1)
            else:
                break
        else:
            assert False, 'startup failed after 10 seconds'

        # click other
        self.click('button#other')
        self.wait_for_attr('div#content', 'innerText', ['other page'])

        # click home
        self.click('button#home')
        self.wait_for_attr('span#value', 'innerText', ['0'])

        # click increment
        self.click('button#value')
        self.wait_for_attr('span#value', 'innerText', ['1'])

        # click increment
        self.click('button#value')
        self.wait_for_attr('span#value', 'innerText', ['2'])

        # data survives page reload and auto increments on page load
        self.load('http://0.0.0.0:8000')
        self.wait_for_attr('span#value', 'innerText', ['3'])

        if not name_mangling:
            # reset db state
            self.js('frontend.state_wipe()')
            self.wait_for_attr('span#value', 'innerText', ['0'])

def test():
    webengine.run_thread(Main, devtools='horizontal')

if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    sys.exit(pytest.main(['test.py', '-svvx', '--tb', 'native']))
