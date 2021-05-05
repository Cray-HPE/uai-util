""" Nox definitations for tests, docs, and linting

Copyright 2019, Cray Inc. All rights reserved.
"""
from __future__ import absolute_import
import os

import nox  # pylint: disable=import-error


COVERAGE_FAIL = 98

PYTHON = False if os.getenv("NOX_DOCKER_BUILD") else ['3']

@nox.session(python=PYTHON)
def lint(session):
    """Run linters.
    Returns a failure if the linters find linting errors or sufficiently
    serious code quality issues.
    """
    run_cmd = ['pylint', 'src']
    if 'prod' not in session.posargs:
        run_cmd.append('--enable=fixme')

    if session.python:
        session.install('-r', 'requirements-lint.txt')
    session.run(*run_cmd)


@nox.session(python=PYTHON)
def style(session):
    """Run code style checker.
    Returns a failure if the style checker fails.
    """
    run_cmd = ['pycodestyle',
               '--config=.pycodestyle',
               'src']
    if 'prod' not in session.posargs:
        # ignore improper import placement, specifically in
        # gen_swagger.py as we have code in there that is needed to
        # prepare for importing tms_app.  Also, ignore warnings about
        # line breaks after binary operators, since there are
        # instances where readability is enhanced by line breaks like
        # that.
        run_cmd.append('--ignore=E402,W504')

    if session.python:
        session.install('-r', 'requirements-style.txt')
    session.run(*run_cmd)


@nox.session(python=PYTHON)
def tests(session):
    """Default unit test session.
    """
    # Install all test dependencies, then install this package in-place.
    path = 'src'
    if session.python:
        session.install('--index-url=http://dst.us.cray.com/dstpiprepo/simple',
                        '--trusted-host=dst.us.cray.com',
                        '-r', 'requirements-test.txt')
        session.install('--index-url=http://dst.us.cray.com/dstpiprepo/simple',
                        '--trusted-host=dst.us.cray.com',
                        '-r', 'requirements.txt')

    # Run py.test against the tests.
    session.run(
        'py.test',
        '--quiet',
        '-W',
        'ignore::DeprecationWarning',
        '--cov=src',
        '--cov-append',
        '--cov-config=.coveragerc',
        '--cov-report=',
        '--cov-fail-under={}'.format(COVERAGE_FAIL),
        os.path.join(path),
    )


@nox.session(python=PYTHON)
def cover(session):
    """Run the final coverage report.
    This outputs the coverage report aggregating coverage from the unit
    test runs, and then erases coverage data.
    """
    if session.python:
        session.install('--index-url=http://dst.us.cray.com/dstpiprepo/simple',
                        '--trusted-host=dst.us.cray.com',
                        'coverage', 'pytest-cov')
    session.run('coverage', 'report', '--show-missing',
                '--fail-under={}'.format(COVERAGE_FAIL))
    session.run('coverage', 'erase')
