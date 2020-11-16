develop:
	pip install -e .[dev]

compile:
	cython -3 multifruits.pyx
	python setup.py build_ext --inplace

test:
	py.test -v

release: compile test
	rm -rf dist/ build/ *.egg-info
	python setup.py sdist
	twine upload dist/*
